// Sondes d'audit : elles confirment les sorties actuelles indésirables,
// elles ne définissent pas le comportement produit attendu après correction.
// Exécutées uniquement dans une copie temporaire du projet.
import Foundation
import Testing
import PDFKit
@testable import WorkTimer

@Suite("Sondes audit iOS 27", .serialized)
@MainActor
struct AuditBehaviorProbes {
    private func date(_ month: Int, _ day: Int = 15) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    @Test func monthlyPDFCoverIncludesOtherMonths() throws {
        let days = [WorkDay(date: date(8), totalHours: 8), WorkDay(date: date(9), totalHours: 9)]
        var theme = PDFService.PDFTheme()
        theme.useDecimalHours = true
        theme.includeSummaryCharts = false
        let data = try #require(PDFService.shared.generateReport(for: date(9), workDays: days, annual: false, theme: theme))
        let pdf = try #require(PDFDocument(data: data))
        let cover = try #require(pdf.page(at: 0)?.string)
        print("AUDIT monthly PDF cover:\n" + cover)
        #expect(cover.contains("17.00"))
        #expect(pdf.pageCount == 2)
    }

    @Test func halfVacationAndHalfWorkDeductFullTarget() {
        let days = [WorkDay(date: date(9), totalHours: 4), WorkDay(date: date(9), type: .halfDayVacation)]
        let balance = WorkTimeCalculations.dailyOvertimeSeconds(from: days, expectedDailyHours: { _ in 8 })
        print("AUDIT half vacation + 4h work, target 8h: \(balance) seconds")
        #expect(balance == -14_400)
    }

    @Test func compensatoryDayMissingFromChartOvertime() {
        let days = [WorkDay(date: date(9, 14), totalHours: 10, overtimeSeconds: 7200), WorkDay(date: date(9, 15), overtimeSeconds: -28800, type: .compensatory)]
        let bars = ChartsDataService.monthlyData(from: days)
        let summary = ChartsDataService.summary(from: days)
        print("AUDIT monthly chart: \(bars[0].overtime) hours; summary: \(summary.overtimeSeconds / 3600) hours")
        #expect(bars[0].overtime == 2)
        #expect(summary.overtimeSeconds == -21_600)
    }

    @Test func trainingCalculatesZeroHours() {
        let day = WorkDay(date: date(9), type: .training)
        day.calculateHours()
        print("AUDIT training totalHours: \(day.totalHours)")
        #expect(day.totalHours == 0)
    }

    @Test func annualCSVCountsHalfVacationAsOne() throws {
        let csv = CSVService.shared.generateYearlyReport(workDays: [WorkDay(date: date(9), type: .halfDayVacation)], year: 2026)
        let total = try #require(csv.split(separator: "\n").first { $0.hasPrefix("TOTAL;") })
        let fields = total.split(separator: ";", omittingEmptySubsequences: false)
        print("AUDIT annual CSV: \(total)")
        #expect(fields[4] == "1")
    }
}
