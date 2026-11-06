//
//  ChartsDataServiceTests.swift
//  WorkTimerTests
//
//  Tests de la logique de calcul des graphiques, extraite de ChartsView.
//

import Testing
import Foundation
@testable import WorkTimer

@Suite("Calculs des graphiques (ChartsDataService)")
struct ChartsDataServiceTests {

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }

    private func makeWorkDay(
        date: Date,
        type: WorkDayType,
        totalHours: Double = 0,
        overtimeSeconds: Int = 0
    ) -> WorkDay {
        let day = WorkDay(date: date, type: type)
        day.totalHours = totalHours
        day.overtimeSeconds = overtimeSeconds
        return day
    }

    // MARK: - Summary

    @Test("Le résumé ne somme les heures que des jours travaillés")
    func summaryCountsOnlyWorkDays() {
        let days = [
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 6), type: .work, totalHours: 8, overtimeSeconds: 1800),
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 7), type: .work, totalHours: 9, overtimeSeconds: 3600),
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 8), type: .vacation)
        ]

        let summary = ChartsDataService.summary(from: days)

        #expect(abs(summary.totalHours - 17.0) < 0.01)
        #expect(summary.workDaysCount == 2)
        #expect(summary.overtimeSeconds == 5400)
        #expect(abs(summary.averageHours - 8.5) < 0.01)
    }

    @Test("Résumé vide pour une liste vide")
    func summaryEmpty() {
        let summary = ChartsDataService.summary(from: [])
        #expect(summary.totalHours == 0)
        #expect(summary.workDaysCount == 0)
        #expect(summary.averageHours == 0)
    }

    // MARK: - Distribution

    @Test("La répartition compte et trie les types par fréquence")
    func distributionCountsAndSorts() {
        let days = [
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 6), type: .work),
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 7), type: .work),
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 8), type: .work),
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 9), type: .vacation)
        ]

        let distribution = ChartsDataService.distributionData(from: days)

        #expect(distribution.count == 2)
        #expect(distribution.first?.type == .work)
        #expect(distribution.first?.count == 3)
        #expect(abs((distribution.first?.percentage ?? 0) - 75.0) < 0.01)
    }

    @Test("Répartition vide pour une liste vide")
    func distributionEmpty() {
        #expect(ChartsDataService.distributionData(from: []).isEmpty)
    }

    // MARK: - Daily

    @Test("La fenêtre quotidienne reste dans l'année sélectionnée")
    func dailyRangeUsesSelectedPastYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 18)))

        let range = try #require(ChartsDateRange.last30Days(in: 2024, relativeTo: now, calendar: calendar))

        #expect(calendar.component(.year, from: range.start) == 2024)
        #expect(calendar.component(.month, from: range.end.addingTimeInterval(-1)) == 12)
        #expect(calendar.component(.year, from: range.end.addingTimeInterval(-1)) == 2024)
    }

    @Test("La fenêtre quotidienne de l'année courante inclut aujourd'hui")
    func dailyRangeIncludesTodayForCurrentYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 18)))

        let range = try #require(ChartsDateRange.last30Days(in: 2026, relativeTo: now, calendar: calendar))

        #expect(range.contains(now))
        #expect(calendar.component(.day, from: range.end) == 19)
    }

    @Test("Les données quotidiennes excluent les jours à 0h et sont triées par date")
    func dailyExcludesZeroHoursAndSorts() {
        let later = makeWorkDay(date: makeDate(year: 2025, month: 1, day: 10), type: .work, totalHours: 8)
        let earlier = makeWorkDay(date: makeDate(year: 2025, month: 1, day: 6), type: .work, totalHours: 7)
        let zero = makeWorkDay(date: makeDate(year: 2025, month: 1, day: 8), type: .vacation, totalHours: 0)

        let daily = ChartsDataService.dailyData(from: [later, zero, earlier])

        #expect(daily.count == 2)
        #expect(daily.first?.date == earlier.date)
        #expect(daily.last?.date == later.date)
    }

    // MARK: - Monthly

    @Test("Les données mensuelles n'incluent que les mois contenant des jours travaillés")
    func monthlyOnlyMonthsWithWork() {
        let days = [
            makeWorkDay(date: makeDate(year: 2025, month: 1, day: 6), type: .work, totalHours: 8),
            makeWorkDay(date: makeDate(year: 1, month: 1, day: 7), type: .work, totalHours: 8),
            makeWorkDay(date: makeDate(year: 2025, month: 3, day: 10), type: .work, totalHours: 9)
        ].filter { Calendar.current.component(.year, from: $0.date) == 2025 }

        let monthly = ChartsDataService.monthlyData(from: days)

        #expect(monthly.count == 2)
        #expect(monthly.map(\.month) == [1, 3])
        #expect(abs((monthly.first?.totalHours ?? 0) - 8.0) < 0.01)
    }

    // MARK: - Ordered Types

    @Test("orderedTypes respecte l'ordre canonique de WorkDayType")
    func orderedTypesFollowsCanonicalOrder() {
        let data = [
            DailyHoursData(date: makeDate(year: 2025, month: 1, day: 6), dayName: "", hours: 8, type: .vacation),
            DailyHoursData(date: makeDate(year: 2025, month: 1, day: 7), dayName: "", hours: 8, type: .work)
        ]

        let ordered = ChartsDataService.orderedTypes(in: data)
        let canonical = WorkDayType.allCases.filter { $0 == .work || $0 == .vacation }

        #expect(ordered == canonical)
    }
}
