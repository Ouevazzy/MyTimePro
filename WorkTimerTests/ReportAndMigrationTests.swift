import Foundation
import PDFKit
import SwiftData
import Testing
@testable import WorkTimer

@MainActor
struct ReportAndMigrationTests {
    @Test func monthlyReportUsesSelectedMonthOnBothPages() throws {
        let calendar = Calendar.current
        let jan = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        let feb = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 2)))
        let entries = [WorkDay(date: jan, totalHours: 8), WorkDay(date: feb, totalHours: 6)]
        var theme = PDFService.PDFTheme()
        theme.useDecimalHours = false
        let data = try #require(PDFService.shared.generateReport(for: feb, workDays: entries, theme: theme))
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount == 2)
        for i in 0..<pdf.pageCount {
            let content = try #require(pdf.page(at: i)?.string)
            #expect(content.contains("6h00"))
            #expect(!content.contains("14h00"))
        }
    }

    @Test func halfDayUsesScheduledHours() {
        let date = Date()
        let work = WorkDay(date: date, totalHours: 3)
        let leave = WorkDay(date: date, type: .halfDayVacation)
        #expect(WorkTimeCalculations.dailyOvertimeSeconds(from: [work, leave], expectedDailyHours: { _ in 6 }) == 0)
    }

    @Test func contractEffectiveDatePreservesPast() throws {
        let settings = UserSettings(store: nil)
        let calendar = Calendar.current
        let november = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 30)))
        let december = try #require(calendar.date(byAdding: .day, value: 1, to: november))
        settings.weeklyHours = 40
        settings.hourlyRate = 30
        settings.editContract(effective: december) { settings.weeklyHours = 35 }
        settings.editContract(effective: december) { settings.hourlyRate = 32 }
        #expect(settings.expectedDailyHours(for: november) == 8)
        #expect(settings.expectedDailyHours(for: december) == 7)
        #expect(settings.hourlyRate(for: november) == 30)
        #expect(settings.hourlyRate(for: december) == 32)
    }

    @Test(arguments: [1, 2, 3]) func migrateFixture(source: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fixture.store")
        do {
            let versions: [any VersionedSchema.Type] = [WorkDaySchemaV1.self, WorkDaySchemaV2.self, WorkDayCompactSchemaV2.self]
            let schema = Schema(versionedSchema: versions[source - 1])
            let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let ctx = ModelContext(store)
            if source == 3 {
                let entry = WorkDayCompactSchemaV2.WorkDay()
                entry.note = "Audit fixture"
                entry.totalHours = 7
                ctx.insert(entry)
            } else if source == 2 {
                let entry = WorkDaySchemaV2.WorkDay()
                entry.note = "Audit fixture"
                entry.totalHours = 7
                entry.isDeleted = true
                ctx.insert(entry)
            } else {
                let entry = WorkDaySchemaV1.WorkDay()
                entry.note = "Audit fixture"
                entry.totalHours = 7
                ctx.insert(entry)
            }
            try ctx.save()
        }
        let schema = Schema([WorkDay.self])
        let store = try ModelContainer(for: schema, migrationPlan: WorkDayMigrationPlan.self, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let ctx = ModelContext(store)
        let entries = try ctx.fetch(FetchDescriptor<WorkDay>())
        #expect(entries.count == 1)
        #expect(entries.first?.totalHours == 7)
        #expect(entries.first?.isDeleted == (source == 2))
        #expect(entries.first?.note == "Audit fixture")
    }
}
