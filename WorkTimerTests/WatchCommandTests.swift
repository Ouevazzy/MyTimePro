//
//  WatchCommandTests.swift
//  WorkTimerTests
//
//  Commandes reçues de la montre (sans le transport WatchConnectivity)
//  et rémunération calculée à partir du taux horaire.
//

import Testing
import Foundation
import SwiftData
@testable import WorkTimer

@Suite("Montre → iPhone — commandes", .serialized)
@MainActor
struct WatchCommandTests {
    private let calendar = Calendar.current

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

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func allDays(_ context: ModelContext) throws -> [WorkDay] {
        try context.fetch(FetchDescriptor<WorkDay>())
    }

    @Test("Une journée de travail créée sur la montre est enregistrée avec ses heures")
    func createWorkDay() throws {
        let context = try makeContext()
        PhoneWatchConnectivity.shared.apply("createDay", message: [
            WatchKeys.type: WorkDayType.work.rawValue,
            WatchKeys.date: at(0).timeIntervalSince1970,
            WatchKeys.start: at(8).timeIntervalSince1970,
            WatchKeys.end: at(17).timeIntervalSince1970,
            WatchKeys.breakSeconds: 3600.0,
            WatchKeys.bonus: 20.0
        ], in: context)

        let days = try allDays(context)
        #expect(days.count == 1)
        let day = try #require(days.first)
        #expect(day.type == .work)
        #expect(calendar.isDate(day.date, inSameDayAs: at(0)))
        #expect(abs(day.totalHours - 8) < 0.001)
        #expect(day.bonusAmount == 20)
    }

    @Test("Un congé créé sur la montre n'a pas d'heures")
    func createVacationDay() throws {
        let context = try makeContext()
        PhoneWatchConnectivity.shared.apply("createDay", message: [
            WatchKeys.type: WorkDayType.vacation.rawValue,
            WatchKeys.date: at(0).timeIntervalSince1970
        ], in: context)

        let day = try #require(try allDays(context).first)
        #expect(day.type == .vacation)
        #expect(day.startTime == nil)
        #expect(day.endTime == nil)
    }

    @Test("Une journée de travail sans heures valides est ignorée")
    func rejectInvalidRange() throws {
        let context = try makeContext()
        PhoneWatchConnectivity.shared.apply("createDay", message: [
            WatchKeys.type: WorkDayType.work.rawValue,
            WatchKeys.date: at(0).timeIntervalSince1970,
            WatchKeys.start: at(17).timeIntervalSince1970,
            WatchKeys.end: at(8).timeIntervalSince1970
        ], in: context)
        PhoneWatchConnectivity.shared.apply("createDay", message: [
            WatchKeys.type: WorkDayType.work.rawValue,
            WatchKeys.date: at(0).timeIntervalSince1970
        ], in: context)

        #expect(try allDays(context).isEmpty)
    }

    @Test("Démarrer, mettre en pause, reprendre puis arrêter enregistre la session")
    func timerCommandsSaveSession() throws {
        let context = try makeContext()
        let timer = TimerManager.shared
        timer.reset()
        defer { timer.reset() }

        let start = Date().addingTimeInterval(-2 * 3600)
        PhoneWatchConnectivity.shared.apply("start", message: [
            WatchKeys.start: start.timeIntervalSince1970
        ], in: context)
        #expect(timer.isActive)

        PhoneWatchConnectivity.shared.apply("pause", message: [:], in: context)
        PhoneWatchConnectivity.shared.apply("resume", message: [:], in: context)
        PhoneWatchConnectivity.shared.apply("stop", message: [
            WatchKeys.end: Date().timeIntervalSince1970
        ], in: context)

        #expect(!timer.isActive)
        let day = try #require(try allDays(context).first)
        #expect(day.type == .work)
        #expect(day.totalHours > 1.9 && day.totalHours < 2.1)
    }

    @Test("Une commande inconnue ne change rien")
    func unknownCommandIsIgnored() throws {
        let context = try makeContext()
        PhoneWatchConnectivity.shared.apply("bogus", message: [:], in: context)
        #expect(try allDays(context).isEmpty)
    }
}

@Suite("Taux horaire — rémunération", .serialized)
@MainActor
struct HourlyRateEarningsTests {
    @Test("Heures × taux + bonus, et rien hors journées de travail")
    func earnings() {
        let settings = UserSettings.shared
        let previousRate = settings.hourlyRate
        defer { settings.hourlyRate = previousRate }
        settings.hourlyRate = 25

        let calendar = Calendar.current
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let work = WorkDay(date: day, type: .work)
        work.updateData(
            startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!,
            endTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)!,
            breakDuration: 3600
        )
        work.bonusAmount = 10
        #expect(abs(work.grossEarnings - (8 * 25 + 10)) < 0.001)

        let vacation = WorkDay(date: day, type: .vacation)
        #expect(vacation.grossEarnings == 0)

        settings.hourlyRate = 0
        #expect(abs(work.grossEarnings - 10) < 0.001)
    }
}
