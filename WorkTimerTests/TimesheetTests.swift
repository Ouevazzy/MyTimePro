//
//  TimesheetTests.swift
//  WorkTimerTests
//

import Foundation
import PDFKit
import Testing
@testable import WorkTimer

@Suite("Feuille d'heures")
struct TimesheetTests {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        Timesheet.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func work(_ day: Date, _ from: Double, _ to: Double, breakMinutes: Int = 0, overtime: Int = 0, note: String? = nil) -> WorkDay {
        WorkDay(date: day, startTime: day.addingTimeInterval(from * 3600), endTime: day.addingTimeInterval(to * 3600),
                breakDuration: Double(breakMinutes) * 60,
                totalHours: to - from - Double(breakMinutes) / 60, overtimeSeconds: overtime, type: .work, note: note)
    }

    /// Semaine 48 de 2026 : du lundi 23 au dimanche 29 novembre.
    private var week: [WorkDay] {
        let monday = date(2026, 11, 23)
        return [
            work(monday, 8, 12, note: "Privé"),
            work(monday, 13, 17.5, overtime: 18 * 60),
            work(date(2026, 11, 24), 8, 17, breakMinutes: 60, overtime: -12 * 60),
            WorkDay(date: date(2026, 11, 25), breakDuration: 0, type: .vacation),
            WorkDay(date: date(2026, 11, 26), breakDuration: 0, type: .sickLeave),
            work(date(2026, 11, 27), 22, 30, breakMinutes: 30),
            work(date(2026, 11, 22), 8, 12), // dimanche précédent
            work(date(2026, 11, 30), 8, 12) // lundi suivant
        ]
    }

    @Test("Semaine du lundi au dimanche, voisines exclues")
    func weekBounds() {
        let sheet = Timesheet(period: .week, containing: date(2026, 11, 29, 23), workDays: week)
        #expect(sheet.start == date(2026, 11, 23))
        #expect(sheet.end == date(2026, 11, 30))
        #expect(sheet.weeks.count == 1)
        #expect(sheet.weeks[0].number == 48)
        #expect(!sheet.weeks[0].isPartial)
        #expect(sheet.days.count == 7)
        #expect(sheet.days[0].entries.count == 2)
        #expect(sheet.days[0].workedMinutes == 510)
        #expect(sheet.workedMinutes == 510 + 480 + 450)
        #expect(sheet.balanceMinutes == 6)
        #expect(sheet.absences.map(\.type) == [.vacation, .sickLeave])
    }

    @Test("Mois complet, semaines coupées signalées")
    func month() {
        let sheet = Timesheet(period: .month, containing: date(2026, 11, 10), workDays: week)
        #expect(sheet.days.count == 30)
        #expect(sheet.weeks.map(\.number) == [44, 45, 46, 47, 48, 49])
        #expect(sheet.weeks.map(\.isPartial) == [true, false, false, false, false, true])
        #expect(sheet.workedMinutes == sheet.weeks.reduce(0) { $0 + $1.workedMinutes })
    }

    @Test("Changement d'heure et passage d'année", arguments: [(2026, 3, 31), (2026, 10, 31), (2027, 1, 31)])
    func boundaries(year: Int, month: Int, count: Int) {
        let sheet = Timesheet(period: .month, containing: date(year, month, 15), workDays: [])
        #expect(sheet.days.count == count)
        #expect(Set(sheet.days.map(\.date)).count == count)
        #expect(sheet.days.allSatisfy { $0.date == Timesheet.calendar.startOfDay(for: $0.date) })
        #expect(sheet.isEmpty)
    }

    @Test("Les totaux sont la somme des lignes affichées")
    func roundingAddsUp() {
        let days = (2...6).map { day -> WorkDay in
            let entry = work(date(2026, 11, day), 8, 12)
            entry.totalHours = 4 + 40.0 / 3600 // 40 s de trop chaque jour
            return entry
        }
        let sheet = Timesheet(period: .week, containing: date(2026, 11, 2), workDays: days)
        #expect(sheet.days.prefix(5).allSatisfy { $0.workedMinutes == 241 })
        #expect(sheet.workedMinutes == 5 * 241)
    }

    @Test("Une entrée supprimée n'apparaît pas")
    func ignoresDeleted() {
        let entry = work(date(2026, 11, 23), 8, 12)
        entry.isDeleted = true
        #expect(Timesheet(period: .week, containing: date(2026, 11, 23), workDays: [entry]).isEmpty)
    }

    @Test("CSV : colonnes, totaux, notes seulement si demandées")
    func csv() throws {
        let sheet = Timesheet(period: .week, containing: date(2026, 11, 23), workDays: week)
        var options = Timesheet.Options(employee: "Test; Nom", company: "Société")
        let lines = sheet.csv(options: options).split(separator: "\n").map(String.init)
        #expect(lines.count == 1 + 8)
        #expect(lines[0].split(separator: ";", omittingEmptySubsequences: false).count == 11)
        #expect(lines[1].hasPrefix("\"Test; Nom\";48;23.11.2026;"))
        #expect(lines[1].contains(";08:00;12:00;0:00;4:00;;;"))
        #expect(lines[2].contains(";13:00;17:30;0:00;4:30;8:30;;+0:18"))
        #expect(lines[3].contains(";08:00;17:00;1:00;8:00;8:00;;-0:12"))
        #expect(lines[4].contains(WorkDayType.vacation.localizedName))
        #expect(lines[6].contains(";22:00;06:00;0:30;7:30;7:30;"))
        #expect(lines[8].hasSuffix(";;24:00;"))
        #expect(!lines.joined().contains("Privé"))

        options.includeNotes = true
        options.useDecimalHours = true
        let detailed = sheet.csv(options: options)
        #expect(detailed.contains("Privé"))
        #expect(detailed.contains(";8.50;"))
        #expect(!detailed.contains("timesheet."))
    }

    @Test("PDF : contenu, une page, signatures, rien de privé", arguments: Timesheet.Period.allCases)
    func pdf(period: Timesheet.Period) throws {
        let days = week
        days[2].bonusAmount = 777
        let sheet = Timesheet(period: period, containing: date(2026, 11, 23), workDays: days)
        let options = Timesheet.Options(employee: "Prénom Nom", company: "Menuiserie Test", locale: PDFService.shared.reportLocale)
        let document = try #require(PDFDocument(data: PDFService.shared.generateTimesheet(sheet, options: options)))
        let text = try #require(document.string)
        #expect(document.pageCount == 1)
        for expected in ["Prénom Nom", "Menuiserie Test", "08:00", "17:30", "8:30", "06:00 (+1)",
                         "timesheet.signature.employee".localized, "timesheet.signature.employer".localized,
                         WorkDayType.sickLeave.localizedName] {
            #expect(text.contains(expected), "Absent : \(expected)")
        }
        #expect(!text.contains("777"))
        #expect(!text.contains("Privé"))
        #expect(!text.contains("timesheet."))
    }

    @Test("PDF : mois chargé sur plusieurs pages, rien de perdu")
    func longPDF() throws {
        let days = (1...30).flatMap { day in
            (0..<3).map { work(date(2026, 11, day), 8 + Double($0) * 3, 10 + Double($0) * 3, note: "Note \(day)-\($0) très longue pour vérifier la coupe") }
        }
        let sheet = Timesheet(period: .month, containing: date(2026, 11, 1), workDays: days)
        #expect(sheet.workedMinutes == 180 * 60)
        let options = Timesheet.Options(employee: "A", company: "B", includeNotes: true, locale: PDFService.shared.reportLocale)
        let document = try #require(PDFDocument(data: PDFService.shared.generateTimesheet(sheet, options: options)))
        #expect(document.pageCount > 1)
        let text = try #require(document.string)
        #expect(text.components(separatedBy: "14:00").count - 1 >= 30)
        #expect(text.contains("180:00"))
        #expect(text.contains("pdf.pageOf".localized(document.pageCount, document.pageCount)))
        let last = try #require(document.page(at: document.pageCount - 1)?.string)
        #expect(last.contains("timesheet.signature.employer".localized))
    }

    @Test("PDF : période vide")
    func emptyPDF() throws {
        let sheet = Timesheet(period: .week, containing: date(2026, 11, 23), workDays: [])
        let document = try #require(PDFDocument(data: PDFService.shared.generateTimesheet(sheet, options: .init())))
        #expect(document.pageCount == 1)
    }
}
