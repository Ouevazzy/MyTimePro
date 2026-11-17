//
//  LiveTimerSessionTests.swift
//  WorkTimerTests
//
//  Sessions de nuit, sessions oubliées et visibilité de la carte chrono.
//

import Testing
import Foundation
import SwiftData
@testable import WorkTimer

@Suite("Formulaire — sessions de nuit")
struct OvernightDraftTests {
    private let calendar = Calendar.current

    private func time(_ hour: Int, on day: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func draft(start: Int, end: Int, endsNextDay: Bool) -> WorkDayFormDraft {
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        return WorkDayFormDraft(
            date: day,
            type: .work,
            startTime: time(start, on: day),
            endTime: time(end, on: day),
            breakDuration: calendar.startOfDay(for: day),
            bonusAmount: 0,
            note: "",
            endsNextDay: endsNextDay
        )
    }

    @Test("Une fin le lendemain compte les heures de nuit")
    func overnightIsValid() {
        let form = draft(start: 22, end: 6, endsNextDay: true)
        #expect(form.validationIssue == nil)
        #expect(form.netWorkedSeconds == TimeInterval(28_800))
    }

    @Test("Sans fin le lendemain, une fin avant le début reste refusée")
    func sameDayEndBeforeStartIsRejected() {
        #expect(draft(start: 22, end: 6, endsNextDay: false).validationIssue == .invalidDuration)
    }

    @Test("Des dernières heures de nuit préremplissent une fin le lendemain")
    func lastNightHoursCrossMidnight() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        #expect(WorkDayFormDraft.crossesMidnight(start: time(22, on: day), end: time(6, on: day)))
        #expect(!WorkDayFormDraft.crossesMidnight(start: time(8, on: day), end: time(17, on: day)))
    }

    @Test("La pause proposée laisse toujours du temps travaillé")
    func suggestedBreakFitsRange() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let start = time(16, on: day)
        let shortEnd = start.addingTimeInterval(60)
        #expect(WorkDayFormDraft.fittingBreak(3600, start: start, end: shortEnd) == TimeInterval(0))
        #expect(WorkDayFormDraft.fittingBreak(3600, start: time(8, on: day), end: time(17, on: day)) == TimeInterval(3600))
        #expect(WorkDayFormDraft.fittingBreak(3600, start: time(22, on: day), end: time(6, on: day)) == TimeInterval(3600))
    }

    @Test("Une plage de plus de 24 h est refusée")
    func moreThanOneDayIsRejected() {
        #expect(draft(start: 8, end: 9, endsNextDay: true).validationIssue == .invalidDuration)
    }
}

@Suite("Chrono — fin de session", .serialized)
@MainActor
struct TimerSessionTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([WorkDay.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return ModelContext(try ModelContainer(for: schema, configurations: configuration))
    }

    @Test("Une session de plus de 24 h reste active et n'est pas enregistrée")
    func tooLongSessionIsKept() throws {
        let context = try makeContext()
        let timer = TimerManager.shared
        timer.reset()
        defer { timer.reset() }

        let start = Date(timeIntervalSince1970: 1_770_000_000)
        timer.start(at: start)
        let outcome = timer.stopAndSave(in: context, at: start.addingTimeInterval(25 * 3600))

        #expect(outcome.result == .tooLong)
        #expect(timer.isActive)
        #expect(try context.fetch(FetchDescriptor<WorkDay>()).isEmpty)
    }

    @Test("Une session qui passe minuit reste rattachée au jour de début")
    func overnightSessionIsSaved() throws {
        let context = try makeContext()
        let timer = TimerManager.shared
        let settings = UserSettings.shared
        let lastTimes = (settings.lastStartTime, settings.lastEndTime)
        timer.reset()
        defer { timer.reset() }

        let calendar = Calendar.current
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let start = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!
        timer.start(at: start)
        let outcome = timer.stopAndSave(in: context, at: start.addingTimeInterval(8 * 3600))

        #expect(outcome.result == .saved)
        #expect(!timer.isActive)
        #expect(outcome.workDay?.date == day)
        #expect(outcome.workDay?.totalHours == 8)
        #expect(settings.lastStartTime == lastTimes.0)
        #expect(settings.lastEndTime == lastTimes.1)
    }
}

@Suite("Chrono — rappel de session oubliée")
struct ForgottenReminderDateTests {
    private let start = Date(timeIntervalSince1970: 1_770_000_000)

    @Test("Le rappel suit l'horaire du jour, les pauses et la marge")
    func usesScheduleBreaksAndGrace() {
        let date = TimerManager.forgottenReminderDate(start: start, expectedHours: 8, pausedSeconds: 1800)
        #expect(date.timeIntervalSince(start) == TimeInterval(8 * 3600 + 1800 + 2 * 3600))
    }

    @Test("Un jour sans horaire prévu retient 8 h")
    func restDayUsesFallback() {
        let date = TimerManager.forgottenReminderDate(start: start, expectedHours: 0, pausedSeconds: 0)
        #expect(date.timeIntervalSince(start) == TimeInterval(10 * 3600))
    }
}

@Suite("Carte chrono — visibilité")
struct LiveTimerVisibilityTests {
    @Test("Une session active reste visible même si la carte est masquée")
    func activeSessionStaysVisible() {
        #expect(LiveTimerCard.isVisible(settingEnabled: false, sessionActive: true))
        #expect(LiveTimerCard.isVisible(settingEnabled: true, sessionActive: false))
        #expect(!LiveTimerCard.isVisible(settingEnabled: false, sessionActive: false))
    }
}
