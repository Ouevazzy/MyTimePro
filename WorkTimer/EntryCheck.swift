//
//  EntryCheck.swift
//  WorkTimer
//
//  Contrôle de saisie : jours oubliés, fins de journée et pauses manquantes.
//  Aide à compléter ses heures, sans juger de la conformité : l'obligation de
//  saisie incombe à l'employeur (art. 46 LTr, art. 73 OLT 1).
//

import Foundation
import SwiftData

struct EntryIssue: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Jour normalement travaillé, sans aucune saisie.
        case missingDay
        /// Travail avec un début mais pas de fin, ou l'inverse.
        case missingEnd
        /// Pauses plus courtes que le minimum de l'art. 15 LTr.
        case shortBreak(minutes: Int, minimum: Int)

        var name: String {
            switch self {
            case .missingDay: "missingDay"
            case .missingEnd: "missingEnd"
            case .shortBreak: "shortBreak"
            }
        }
    }

    let date: Date
    let kind: Kind
    /// Saisie à ouvrir ; nil pour créer la journée.
    let entryID: UUID?

    /// Stable d'un lancement à l'autre, pour mémoriser les jours ignorés.
    var id: String {
        let parts = EntryCheck.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d:%@", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, kind.name)
    }
}

enum EntryCheck {
    /// Nombre de jours passés examinés.
    static let windowDays = 60

    static var calendar: Calendar { Timesheet.calendar }

    /// Pause minimale en minutes (art. 15 al. 1 LTr) pour une durée travaillée.
    static func minimumBreak(forWorkedMinutes minutes: Int) -> Int {
        switch minutes {
        case let m where m > 9 * 60: 60
        case let m where m > 7 * 60: 30
        case let m where m > 5 * 60 + 30: 15
        default: 0
        }
    }

    /// Anomalies des jours passés, la plus récente d'abord. Aujourd'hui est exclu :
    /// la journée n'est pas finie.
    static func issues(
        in workDays: [WorkDay],
        firstDay: Date,
        today: Date,
        runningTimerStart: Date? = nil,
        expectedHours: (Date) -> Double,
        isHoliday: (Date) -> Bool
    ) -> [EntryIssue] {
        let calendar = calendar
        let byDay = Dictionary(grouping: workDays.filter { !$0.isDeleted }) { calendar.startOfDay(for: $0.date) }
        let runningDay = runningTimerStart.map { calendar.startOfDay(for: $0) }
        let end = calendar.startOfDay(for: today)
        var day = calendar.startOfDay(for: firstDay)
        var issues: [EntryIssue] = []

        while day < end {
            let entries = byDay[day] ?? []
            if entries.isEmpty {
                // Un chrono parti ce jour-là et toujours actif n'est pas un oubli de saisie.
                if expectedHours(day) > 0, !isHoliday(day), day != runningDay {
                    issues.append(EntryIssue(date: day, kind: .missingDay, entryID: nil))
                }
            } else if let open = entries.first(where: {
                $0.type == .work && ($0.startTime == nil || $0.endTime == nil)
            }) {
                issues.append(EntryIssue(date: day, kind: .missingEnd, entryID: open.id))
            } else if let issue = breakIssue(on: day, entries: entries) {
                issues.append(issue)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = calendar.startOfDay(for: next)
        }
        return issues.reversed()
    }

    private static func breakIssue(on day: Date, entries: [WorkDay]) -> EntryIssue? {
        let ranges = entries
            .filter { $0.type == .work && $0.startTime != nil && $0.endTime != nil }
            .sorted { $0.startTime! < $1.startTime! }
        guard let longest = ranges.max(by: { $0.totalHours < $1.totalHours }) else { return nil }

        let worked = Int((ranges.reduce(0) { $0 + $1.totalHours } * 60).rounded())
        // L'intervalle entre deux plages est aussi une pause (8–12 h, 13–17 h).
        var pause = ranges.reduce(0) { $0 + $1.breakDuration }
        var lastEnd = ranges[0].endTime!
        for range in ranges.dropFirst() {
            pause += max(0, range.startTime!.timeIntervalSince(lastEnd))
            lastEnd = max(lastEnd, range.endTime!)
        }
        let minutes = Int((pause / 60).rounded())
        let minimum = minimumBreak(forWorkedMinutes: worked)
        guard minutes < minimum else { return nil }
        return EntryIssue(date: day, kind: .shortBreak(minutes: minutes, minimum: minimum), entryID: longest.id)
    }

    // MARK: - Jours ignorés

    private static let ignoredKey = "entryCheck.ignored"

    static func ignored(in store: UserDefaults = .standard) -> Set<String> {
        Set(store.stringArray(forKey: ignoredKey) ?? [])
    }

    static func ignore(_ issue: EntryIssue, in store: UserDefaults = .standard) {
        store.set(Array(ignored(in: store).union([issue.id])).sorted(), forKey: ignoredKey)
    }

    static func clearIgnored(in store: UserDefaults = .standard) {
        store.removeObject(forKey: ignoredKey)
    }

    // MARK: - Chargement

    /// Anomalies actuelles, ignorées comprises. Le contrôle commence à la première
    /// journée travaillée : rien n'est réclamé avant l'utilisation de l'app.
    @MainActor
    static func load(
        in context: ModelContext,
        settings: UserSettings = .shared,
        region: SwissHolidayRegion?,
        timerStart: Date? = TimerManager.shared.startDate,
        today: Date = Date()
    ) throws -> [EntryIssue] {
        let work = WorkDayType.work.rawValue
        var firstDescriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate { $0.typeRawValue == work && !$0.isDeleted },
            sortBy: [SortDescriptor(\.date)]
        )
        firstDescriptor.fetchLimit = 1
        guard let first = try context.fetch(firstDescriptor).first?.date else { return [] }

        let end = calendar.startOfDay(for: today)
        let window = calendar.date(byAdding: .day, value: -windowDays, to: end) ?? end
        let start = max(calendar.startOfDay(for: first), window)
        guard start < end else { return [] }

        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate { $0.date >= start && $0.date < end && !$0.isDeleted },
            sortBy: [SortDescriptor(\.date)]
        )
        // Un 1er mai férié l'après-midi seulement reste un jour travaillé.
        let years = Set([start, end].map { calendar.component(.year, from: $0) })
        let holidays = Set(years.flatMap { region?.holidays(in: $0) ?? [] }
            .filter { !$0.isAfternoonOnly }
            .map { calendar.startOfDay(for: $0.date) })

        return issues(
            in: try context.fetch(descriptor),
            firstDay: start,
            today: today,
            runningTimerStart: timerStart,
            expectedHours: { settings.expectedDailyHours(for: $0) },
            isHoliday: { holidays.contains($0) }
        )
    }
}
