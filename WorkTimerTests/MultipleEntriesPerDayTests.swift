import Foundation
import SwiftData
import Testing
@testable import WorkTimer

@Suite("Plusieurs entrées par journée")
struct MultipleEntriesPerDayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }()

    @Test("4 h + 6 h avec une cible de 9 h donnent 1 h supplémentaire")
    func twoEntriesShareOneDailyTarget() throws {
        let date = try makeDate(year: 2026, month: 7, day: 20)
        let first = WorkDay(date: date, totalHours: 4, overtimeSeconds: -18_000, type: .work)
        let second = WorkDay(date: date, totalHours: 6, overtimeSeconds: -10_800, type: .work)

        WorkDay.reconcileDailyOvertime(
            for: [first, second],
            calendar: calendar,
            expectedDailyHours: { _ in 9 }
        )

        #expect(first.totalHours + second.totalHours == 10)
        #expect(first.overtimeSeconds + second.overtimeSeconds == 3_600)
        #expect([first.overtimeSeconds, second.overtimeSeconds].filter { $0 != 0 } == [3_600])
    }

    @Test("une seule entrée de 4 h conserve un déficit de 5 h")
    func oneEntryKeepsDailyDeficit() throws {
        let date = try makeDate(year: 2026, month: 7, day: 20)
        let entry = WorkDay(date: date, totalHours: 4, type: .work)

        WorkDay.reconcileDailyOvertime(
            for: [entry],
            calendar: calendar,
            expectedDailyHours: { _ in 9 }
        )

        #expect(entry.overtimeSeconds == -18_000)
    }

    @Test("la réconciliation SwiftData inclut les nouvelles entrées avant la sauvegarde")
    @MainActor
    func insertedEntriesAreReconciledBeforeSave() throws {
        let schema = Schema([WorkDay.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        let date = try makeDate(year: 2026, month: 7, day: 20)
        let first = WorkDay(date: date, totalHours: 4, type: .work)
        let second = WorkDay(date: date, totalHours: 6, type: .work)
        context.insert(first)
        context.insert(second)

        _ = try WorkDay.reconcileDailyOvertime(
            in: context,
            for: [date],
            calendar: calendar,
            expectedDailyHours: { _ in 9 }
        )
        try context.save()

        let saved = try context.fetch(FetchDescriptor<WorkDay>())
        #expect(saved.count == 2)
        #expect(saved.reduce(0) { $0 + $1.overtimeSeconds } == 3_600)
    }

    @Test("supprimer une entrée recalcule le solde des entrées restantes")
    @MainActor
    func deletionRecalculatesRemainingEntry() throws {
        let schema = Schema([WorkDay.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        let date = try makeDate(year: 2026, month: 7, day: 20)
        let first = WorkDay(date: date, totalHours: 4, type: .work)
        let second = WorkDay(date: date, totalHours: 6, type: .work)
        context.insert(first)
        context.insert(second)
        _ = try WorkDay.reconcileDailyOvertime(
            in: context,
            for: [date],
            calendar: calendar,
            expectedDailyHours: { _ in 9 }
        )
        try context.save()

        context.delete(second)
        _ = try WorkDay.reconcileDailyOvertime(
            in: context,
            for: [date],
            calendar: calendar,
            expectedDailyHours: { _ in 9 }
        )
        try context.save()

        let saved = try context.fetch(FetchDescriptor<WorkDay>())
        #expect(saved.count == 1)
        #expect(saved.first?.overtimeSeconds == -18_000)
    }

    @Test("les statistiques comptent une date travaillée une seule fois")
    func statisticsCountUniqueWorkedDates() throws {
        let date = try makeDate(year: 2026, month: 7, day: 20)
        let first = WorkDay(date: date, totalHours: 4, type: .work)
        let second = WorkDay(date: date, totalHours: 6, type: .work)
        WorkDay.reconcileDailyOvertime(
            for: [first, second],
            calendar: calendar,
            expectedDailyHours: { _ in 9 }
        )

        let stats = StatsCalculationService.aggregate(days: [first, second]).year
        let chartSummary = ChartsDataService.summary(from: [first, second])
        let dailyChart = ChartsDataService.dailyData(from: [first, second])

        #expect(stats.workDays == 1)
        #expect(stats.totalHours == 10)
        #expect(stats.overtimeSeconds == 3_600)
        #expect(chartSummary.workDaysCount == 1)
        #expect(chartSummary.averageHours == 10)
        #expect(dailyChart.count == 1)
        #expect(dailyChart.first?.hours == 10)
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
