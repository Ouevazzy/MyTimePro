//
//  EntryCheckTests.swift
//  WorkTimerTests
//

import Foundation
import SwiftData
import Testing
@testable import WorkTimer

@MainActor
@Suite("Contrôle de saisie", .serialized)
struct EntryCheckTests {
    private func day(_ day: Int, month: Int = 11, hour: Double = 0) -> Date {
        EntryCheck.calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
            .addingTimeInterval(hour * 3600)
    }

    private func work(_ date: Int, _ from: Double, _ to: Double, pause: Int = 60) -> WorkDay {
        WorkDay(date: day(date), startTime: day(date, hour: from), endTime: day(date, hour: to),
                breakDuration: Double(pause) * 60, totalHours: to - from - Double(pause) / 60, type: .work)
    }

    /// Du lundi 23 au vendredi 27 novembre 2026, contrôlé le samedi 28.
    private func check(_ days: [WorkDay], timer: Date? = nil, holidays: Set<Date> = [],
                       hours: @escaping (Date) -> Double = { EntryCheck.calendar.isDateInWeekend($0) ? 0 : 8 }) -> [EntryIssue] {
        EntryCheck.issues(in: days, firstDay: day(23), today: day(28, hour: 9), runningTimerStart: timer,
                          expectedHours: hours, isHoliday: { holidays.contains($0) })
    }

    private var fullWeek: [WorkDay] { (23...27).map { work($0, 8, 17) } }

    @Test("Semaine complète : rien à signaler")
    func complete() {
        #expect(check(fullWeek).isEmpty)
    }

    @Test("Jours oubliés, le plus récent d'abord")
    func missingDays() {
        let issues = check([work(23, 8, 17), work(25, 8, 17)])
        #expect(issues.map(\.kind) == [.missingDay, .missingDay, .missingDay])
        #expect(issues.map(\.date) == [day(27), day(26), day(24)])
        #expect(issues.allSatisfy { $0.entryID == nil })
        #expect(issues.first?.id == "2026-11-27:missingDay")
    }

    @Test("Une absence n'est pas un oubli", arguments: [
        WorkDayType.vacation, .halfDayVacation, .sickLeave, .holiday, .compensatory, .training
    ])
    func absences(type: WorkDayType) {
        #expect(check(Array(fullWeek.dropLast()) + [WorkDay(date: day(27), breakDuration: 0, type: type)]).isEmpty)
    }

    @Test("Ni week-end, ni jour non prévu, ni férié, ni aujourd'hui")
    func daysNotExpected() {
        let weekend = EntryCheck.issues(in: [], firstDay: day(28), today: day(30), expectedHours: {
            EntryCheck.calendar.isDateInWeekend($0) ? 0 : 8
        }, isHoliday: { _ in false })
        #expect(weekend.isEmpty)
        // Horaire personnalisé : congé le vendredi.
        #expect(check(Array(fullWeek.dropLast()), hours: { $0 == self.day(27) ? 0 : 8 }).isEmpty)
        #expect(check(Array(fullWeek.dropLast()), holidays: [day(27)]).isEmpty)
        #expect(EntryCheck.issues(in: [], firstDay: day(27), today: day(27, hour: 23), expectedHours: { _ in 8 },
                                  isHoliday: { _ in false }).isEmpty)
    }

    @Test("Chrono encore actif depuis la veille : pas un oubli")
    func runningTimer() {
        let days = Array(fullWeek.dropLast())
        #expect(check(days, timer: day(27, hour: 22)).isEmpty)
        #expect(check(days, timer: day(28, hour: 8)).count == 1)
    }

    @Test("Fin manquante, avec la saisie à ouvrir")
    func missingEnd() throws {
        let open = WorkDay(date: day(27), startTime: day(27, hour: 8), type: .work)
        let issue = try #require(check(Array(fullWeek.dropLast()) + [open]).first)
        #expect(issue.kind == .missingEnd)
        #expect(issue.entryID == open.id)
    }

    @Test("Seuils de l'art. 15 LTr", arguments: [
        (330, 0), (331, 15), (420, 15), (421, 30), (540, 30), (541, 60)
    ])
    func thresholds(worked: Int, minimum: Int) {
        #expect(EntryCheck.minimumBreak(forWorkedMinutes: worked) == minimum)
    }

    @Test("Pause trop courte, suffisante, ou entre deux plages")
    func breaks() throws {
        let base = Array(fullWeek.dropLast())
        let short = try #require(check(base + [work(27, 8, 16.5, pause: 15)]).first)
        #expect(short.kind == .shortBreak(minutes: 15, minimum: 30))
        #expect(check(base + [work(27, 8, 16.5, pause: 30)]).isEmpty)
        // 8–12 h puis 13–17 h : l'heure de midi compte.
        #expect(check(base + [work(27, 8, 12, pause: 0), work(27, 13, 17, pause: 0)]).isEmpty)
        // Sans interruption réelle : signalé.
        #expect(check(base + [work(27, 8, 12, pause: 0), work(27, 12, 16, pause: 0)]).map(\.kind)
                == [.shortBreak(minutes: 0, minimum: 30)])
        #expect(check(base + [work(27, 8, 13, pause: 0)]).isEmpty)
        // Plages qui se chevauchent : pas de pause négative.
        #expect(check(base + [work(27, 8, 13, pause: 0), work(27, 12, 16, pause: 0)]).map(\.kind)
                == [.shortBreak(minutes: 0, minimum: 30)])
    }

    @Test("Session de nuit : rattachée au jour du début")
    func nightSession() {
        #expect(check(Array(fullWeek.dropLast()) + [work(27, 22, 30, pause: 30)]).isEmpty)
    }

    @Test("Entrée supprimée : le jour redevient oublié")
    func deleted() {
        let days = fullWeek
        days[4].isDeleted = true
        #expect(check(days).map(\.kind) == [.missingDay])
    }

    @Test("Ignorer puis réafficher")
    func ignoring() throws {
        let store = try #require(UserDefaults(suiteName: "EntryCheckTests"))
        store.removePersistentDomain(forName: "EntryCheckTests")
        let issue = EntryIssue(date: day(27), kind: .missingDay, entryID: nil)
        EntryCheck.ignore(issue, in: store)
        EntryCheck.ignore(issue, in: store)
        #expect(EntryCheck.ignored(in: store) == [issue.id])
        EntryCheck.clearIgnored(in: store)
        #expect(EntryCheck.ignored(in: store).isEmpty)
    }

    @Test("Chargement : dès la première journée travaillée, 60 jours au plus, fériés du canton")
    func loading() throws {
        let schema = Schema([WorkDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let settings = UserSettings(store: nil)
        func load(_ region: SwissHolidayRegion?, today: Date) throws -> [EntryIssue] {
            try EntryCheck.load(in: context, settings: settings, region: region, timerStart: nil, today: today)
        }
        #expect(try load(nil, today: day(28)).isEmpty) // aucune saisie

        // Un férié ajouté en janvier ne fait pas démarrer le contrôle.
        context.insert(WorkDay(date: day(1, month: 1), breakDuration: 0, type: .holiday))
        context.insert(work(26, 8, 17))
        try context.save()
        #expect(try load(nil, today: day(28)).map(\.date) == [day(27)])

        // Valais : 8 décembre férié (mardi), Vaud non.
        let december = day(10, month: 12)
        #expect(try load(.VD, today: december).contains { $0.date == day(8, month: 12) })
        #expect(try !load(.VS, today: december).contains { $0.date == day(8, month: 12) })

        // Loin dans le temps : fenêtre de 60 jours, passage d'année compris.
        let later = EntryCheck.calendar.date(from: DateComponents(year: 2027, month: 3, day: 1))!
        let issues = try load(.VS, today: later)
        #expect(issues.allSatisfy { EntryCheck.calendar.dateComponents([.day], from: $0.date, to: later).day! <= 60 })
        let newYear = EntryCheck.calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        #expect(!issues.contains { $0.date == newYear })
        // Soleure : 1er mai férié l'après-midi seulement, toujours attendu (vendredi en 2026).
        context.insert(WorkDay(date: day(27, month: 4), startTime: day(27, month: 4, hour: 8),
                               endTime: day(27, month: 4, hour: 12), breakDuration: 0, totalHours: 4, type: .work))
        try context.save()
        #expect(try load(.SO, today: day(4, month: 5)).contains { $0.date == day(1, month: 5) })
        #expect(try !load(.ZH, today: day(4, month: 5)).contains { $0.date == day(1, month: 5) })
    }
}
