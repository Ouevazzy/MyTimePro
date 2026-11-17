import Foundation
import SwiftData
import SwiftUI

@Model
final class WorkDay {
    #Index<WorkDay>([\.date], [\.typeRawValue], [\.isDeleted], [\.needsSync], [\.date, \.isDeleted])

    // MARK: - Properties
    var id: UUID = UUID()
    var schemaRevision: Int = 3
    var cloudKitRecordID: String?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isDeleted: Bool = false
    var needsSync: Bool = true
    var date: Date = Date()
    var startTime: Date?
    var endTime: Date?
    var breakDuration: TimeInterval = 3600
    var totalHours: Double = 0.0
    var overtimeSeconds: Int = 0
    var typeRawValue: String = WorkDayType.work.rawValue
    var note: String?
    var bonusAmount: Double = 0.0

    // MARK: - Computed Properties
    var type: WorkDayType {
        get { WorkDayType(rawValue: typeRawValue) ?? .work }
        set {
            typeRawValue = newValue.rawValue
            markModified()
        }
    }

    var shouldSync: Bool {
        needsSync && !isDeleted
    }

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        breakDuration: TimeInterval = 3600,
        totalHours: Double = 0.0,
        overtimeSeconds: Int = 0,
        type: WorkDayType = .work,
        note: String? = nil,
        bonusAmount: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.breakDuration = breakDuration
        self.totalHours = totalHours
        self.overtimeSeconds = overtimeSeconds
        self.type = type
        self.note = note
        self.bonusAmount = bonusAmount
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Public Methods
    func calculateHours() {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        var standardSeconds = 0

        if type == .work || type == .compensatory {
            standardSeconds = Int(round(settings.expectedDailyHours(for: date, calendar: calendar) * 3600))
        }

        totalHours = 0
        overtimeSeconds = 0

        switch type {
        case .work:
            guard let start = startTime, let end = endTime else { return }
            totalHours = WorkTimeCalculations.calculateTotalHours(
                startTime: start, endTime: end, breakDuration: breakDuration
            )
            overtimeSeconds = Int(round(totalHours * 3600)) - standardSeconds
        case .vacation, .halfDayVacation, .sickLeave, .holiday:
            break
        case .compensatory:
            overtimeSeconds = -standardSeconds
        case .training:
            totalHours = Double(standardSeconds) / 3600.0
        }

        if !type.isWorkDay {
            startTime = nil
            endTime = nil
            breakDuration = 0
            bonusAmount = 0
        }

        markModified()
    }

    func updateData(startTime: Date?, endTime: Date?, breakDuration: TimeInterval) {
        if type.isWorkDay {
            self.startTime = startTime
            self.endTime = endTime
            if let s = startTime, let e = endTime, e >= s {
                let worked = max(0, e.timeIntervalSince(s))
                self.breakDuration = min(max(0, breakDuration), worked)
            } else {
                self.breakDuration = max(0, breakDuration)
            }
        }
        calculateHours()
    }

    func markSynced(recordID: String? = nil) {
        cloudKitRecordID = recordID ?? cloudKitRecordID
        needsSync = false
    }

    // MARK: - Formatted Properties
    var formattedTotalHours: String {
        UserSettings.shared.useDecimalHours
            ? String(format: "%.2f", totalHours)
            : formatTimeInterval(totalHours * 3600)
    }

    var formattedOvertimeHours: String {
        UserSettings.shared.useDecimalHours
            ? String(format: "%.2f", Double(overtimeSeconds) / 3600.0)
            : formatTimeInterval(Double(overtimeSeconds))
    }

    // MARK: - Rémunération
    /// Rémunération brute estimée : heures travaillées × taux horaire global + bonus.
    /// Le taux est global (défini dans les réglages) ; 0 si non configuré.
    var grossEarnings: Double {
        let base = type.isWorkDay ? totalHours * UserSettings.shared.hourlyRate : 0
        return base + bonusAmount
    }

    var formattedEarnings: String {
        UserSettings.shared.formatCurrency(grossEarnings)
    }

    // MARK: - Private Helpers
    private func formatTimeInterval(_ seconds: Double) -> String {
        let totalMinutes = Int(round(seconds / 60))
        let hours = abs(totalMinutes / 60)
        let minutes = abs(totalMinutes % 60)
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }

    private func markModified() {
        modifiedAt = Date()
        needsSync = true
    }
}

// MARK: - Maintenance
extension WorkDay {
    /// Répartit le solde de chaque date sur une seule entrée porteuse.
    /// Les agrégateurs historiques peuvent ainsi continuer à sommer
    /// `overtimeSeconds` sans déduire plusieurs fois la cible quotidienne.
    @discardableResult
    static func reconcileDailyOvertime(
        for entries: [WorkDay],
        calendar: Calendar = .current,
        expectedDailyHours: ((Date) -> Double)? = nil
    ) -> Int {
        let activeEntries = entries.filter { !$0.isDeleted }
        let grouped = Dictionary(grouping: activeEntries) {
            calendar.startOfDay(for: $0.date)
        }
        var changedCount = 0

        for dayEntries in grouped.values {
            let dailyBalance = WorkTimeCalculations.dailyOvertimeSeconds(
                from: dayEntries,
                calendar: calendar,
                expectedDailyHours: expectedDailyHours
            )
            let carrier = dailyOvertimeCarrier(in: dayEntries)

            for entry in dayEntries {
                let newValue = entry.id == carrier?.id ? dailyBalance : 0
                guard entry.overtimeSeconds != newValue else { continue }
                entry.overtimeSeconds = newValue
                entry.markModified()
                changedCount += 1
            }
        }

        return changedCount
    }

    /// Réconcilie uniquement les dates touchées par une création, modification
    /// ou suppression afin de garder les sauvegardes courantes en O(nombre
    /// d'entrées du jour), indépendamment de la taille de l'historique.
    @discardableResult
    static func reconcileDailyOvertime(
        in context: ModelContext,
        for dates: [Date],
        calendar: Calendar = .current,
        expectedDailyHours: ((Date) -> Double)? = nil
    ) throws -> Int {
        let normalizedDates = Set(dates.map { calendar.startOfDay(for: $0) })
        guard let firstDate = normalizedDates.min(),
              let lastDate = normalizedDates.max(),
              let endDate = calendar.date(byAdding: .day, value: 1, to: lastDate)
        else { return 0 }

        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { day in
                day.date >= firstDate && day.date < endDate && !day.isDeleted
            }
        )
        let entries = try context.fetch(descriptor).filter {
            normalizedDates.contains(calendar.startOfDay(for: $0.date))
        }
        return reconcileDailyOvertime(
            for: entries,
            calendar: calendar,
            expectedDailyHours: expectedDailyHours
        )
    }

    /// Corrige les anciennes données créées avant la prise en charge de
    /// plusieurs entrées par date. Aucun champ n'est modifié si les soldes sont
    /// déjà cohérents.
    @discardableResult
    static func reconcileAllDailyOvertime(
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Int {
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { !$0.isDeleted }
        )
        return reconcileDailyOvertime(
            for: try context.fetch(descriptor),
            calendar: calendar
        )
    }

    private static func dailyOvertimeCarrier(in entries: [WorkDay]) -> WorkDay? {
        let workedCandidates = entries.filter {
            ($0.type == .work || $0.type == .training) && $0.totalHours > 0
        }
        let candidates = workedCandidates.isEmpty
            ? entries.filter { $0.type == .compensatory }
            : workedCandidates

        return candidates.min { lhs, rhs in
            let lhsTime = lhs.startTime ?? lhs.createdAt
            let rhsTime = rhs.startTime ?? rhs.createdAt
            if lhsTime != rhsTime { return lhsTime < rhsTime }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Supprime les entrées fantômes : WorkDay de type travail avec 0h et sans horaires.
    /// Source unique partagée par le nettoyage au lancement et la tâche d'arrière-plan.
    /// Retourne le nombre d'entrées supprimées.
    @discardableResult
    static func deleteGhostEntries(in context: ModelContext) throws -> Int {
        let workType = WorkDayType.work.rawValue
        // Prédicat simplifié pour aider le compilateur Swift.
        let predicate = #Predicate<WorkDay> {
            $0.totalHours == 0 && $0.typeRawValue == workType
        }
        let candidates = try context.fetch(FetchDescriptor<WorkDay>(predicate: predicate))
        // Filtrage supplémentaire en mémoire : seules les entrées sans horaire de début.
        let ghosts = candidates.filter { $0.startTime == nil }
        guard !ghosts.isEmpty else { return 0 }
        for ghost in ghosts { context.delete(ghost) }
        try context.save()
        return ghosts.count
    }

    /// Réapplique les horaires de travail courants à toutes les journées existantes.
    /// Recalcule `overtimeSeconds` (et `totalHours` pour les formations) à partir de
    /// `UserSettings.expectedDailyHours(for:)`. Retourne le nombre de journées modifiées.
    @discardableResult
    static func recalculateOvertime(in context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { !$0.isDeleted }
        )
        let days = try context.fetch(descriptor)
        let previousValues = Dictionary(uniqueKeysWithValues: days.map {
            ($0.id, ($0.totalHours, $0.overtimeSeconds))
        })

        for day in days {
            switch day.type {
            case .work, .compensatory, .training:
                day.calculateHours()
            case .vacation, .halfDayVacation, .sickLeave, .holiday:
                continue
            }
        }

        _ = reconcileDailyOvertime(for: days)
        let updatedCount = days.reduce(into: 0) { count, day in
            guard let previous = previousValues[day.id] else { return }
            if abs(day.totalHours - previous.0) > 0.000_1
                || day.overtimeSeconds != previous.1 {
                count += 1
            }
        }

        if updatedCount > 0 {
            try context.save()
        }
        return updatedCount
    }
}

// MARK: - Validation
extension WorkDay {
    var isValid: Bool {
        if type.isWorkDay {
            guard let start = startTime, let end = endTime else { return false }
            guard end > start else { return false }
            guard breakDuration >= 0 else { return false }
            guard bonusAmount >= 0 else { return false }
            let duration = end.timeIntervalSince(start)
            guard duration <= 24 * 3600 else { return false }
            guard breakDuration <= duration else { return false }
        }
        let calendar = Calendar.current
        let maxFuture = calendar.date(byAdding: .year, value: 1,   to: Date()) ?? Date.distantFuture
        let minPast   = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        guard date >= minPast && date <= maxFuture else { return false }
        if let note = note, note.count > 500 { return false }
        return true
    }
}
