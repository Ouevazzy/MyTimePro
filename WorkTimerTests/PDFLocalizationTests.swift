//
//  PDFLocalizationTests.swift
//  WorkTimerTests
//
//  Le rapport PDF suit la langue de l'app : aucun texte français en dur
//  ni clé de traduction non résolue.
//

import Testing
import Foundation
import PDFKit
@testable import WorkTimer

@Suite("PDF — langue du rapport")
struct PDFLocalizationTests {
    private func reportText(annual: Bool) throws -> String {
        let calendar = Calendar.current
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let work = WorkDay(date: day, type: .work)
        work.updateData(
            startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!,
            endTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)!,
            breakDuration: 3600
        )
        let data = try #require(PDFService.shared.generateReport(for: day, workDays: [work], annual: annual))
        let document = try #require(PDFDocument(data: data))
        return try #require(document.string)
    }

    @Test("Les textes du rapport viennent des traductions", arguments: [false, true])
    func reportIsLocalized(annual: Bool) throws {
        let text = try reportText(annual: annual)
        let language = Bundle.main.preferredLocalizations.first ?? "?"

        #expect(!text.contains("pdf."), "Clé de traduction non résolue")
        #expect(text.contains("pdf.summary".localized))
        #expect(text.contains("pdf.table.continued".localized) || text.contains("pdf.table.date".localized))
        if language != "fr" {
            for french in ["Généré le", "Jours travaillés", "Résumé", " sur "] {
                #expect(!text.contains(french), "Texte français en dur : \(french)")
            }
        }
    }
}
