import Foundation
import Testing
@testable import WorkTimer

@Suite("Export CSV")
struct CSVServiceTests {
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }

    @Test("L'export detaille echappe les notes avec separateur, guillemets et retour ligne")
    func detailedExportEscapesDangerousNoteCharacters() {
        let date = makeDate(year: 2026, month: 6, day: 6)
        let workDay = WorkDay(
            date: date,
            startTime: makeDate(year: 2026, month: 6, day: 6, hour: 8),
            endTime: makeDate(year: 2026, month: 6, day: 6, hour: 17),
            breakDuration: 3600,
            totalHours: 8,
            overtimeSeconds: 3600,
            type: .work,
            note: "Site; \"North\"\nLevel 2",
            bonusAmount: 12.5
        )

        let csv = CSVService.shared.generateDetailedExport(
            workDays: [workDay],
            useDecimalHours: true
        )

        #expect(csv.contains("\"Site; \"\"North\"\"\nLevel 2\""))
        #expect(csv.contains(";8.00;1.00;12.50;"))
    }

    @Test("Les donnees CSV partagees commencent par un BOM UTF-8 pour Excel")
    func csvDataAddsUTF8BOM() throws {
        let data = try #require(CSVService.shared.csvData(content: "Date;Type\n"))

        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    @Test("L'export complet utilise le format detaille avec separateur point-virgule")
    func fullExportUsesDetailedSemicolonFormat() throws {
        let workDay = WorkDay(
            date: makeDate(year: 2026, month: 6, day: 6),
            totalHours: 7.5,
            overtimeSeconds: -1800,
            type: .training,
            note: "Formation"
        )

        let csv = CSVService.shared.generateFullExport(workDays: [workDay])
        let firstLine = try #require(csv.split(separator: "\n").first)

        #expect(firstLine.contains(";"))
        #expect(!firstLine.contains(","))
    }
}
