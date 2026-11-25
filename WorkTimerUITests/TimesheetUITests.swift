//
//  TimesheetUITests.swift
//  WorkTimerUITests
//
//  Feuille d'heures : période, aperçu PDF, CSV, et achat proposé sans Pro.
//

import XCTest

final class TimesheetUITests: XCTestCase {
    private struct Texts {
        let code, locale, calendar, save, settings, export, timesheet, week, month, close, preview: String
    }

    private let french = Texts(code: "fr", locale: "fr_CH", calendar: "Calendrier", save: "Enregistrer",
        settings: "Réglages", export: "Exportation", timesheet: "Feuille d'heures", week: "Semaine", month: "Mois", close: "Fermer", preview: "Aperçu")
    private let english = Texts(code: "en", locale: "en_CH", calendar: "Calendar", save: "Save",
        settings: "Settings", export: "Export", timesheet: "Timesheet", week: "Week", month: "Month", close: "Close", preview: "Preview")
    private let german = Texts(code: "de-CH", locale: "de_CH", calendar: "Kalender", save: "Speichern",
        settings: "Einstellungen", export: "Export", timesheet: "Stundenblatt", week: "Woche", month: "Monat", close: "Schliessen", preview: "Vorschau")

    override func setUp() { continueAfterFailure = false }

    func testFrench() { check(french) }
    func testEnglish() { check(english) }
    func testSwissGerman() { check(german) }

    func testRequiresPro() {
        let app = launch(french, pro: false)
        openTimesheet(app, french)
        XCTAssertTrue(app.staticTexts["Passez à Pro"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["timesheet.period.title"].exists)
        keep(app, "fr-achat")
    }

    private func check(_ t: Texts) {
        let app = launch(t, pro: true)
        app.tabBars.buttons[t.calendar].tap()
        app.buttons["calendar.add"].tap()
        app.buttons[t.save].firstMatch.tap()

        openTimesheet(app, t)
        let title = app.staticTexts["timesheet.period.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.buttons[t.week].firstMatch.tap()
        let week = title.label
        XCTAssertTrue(week.hasPrefix(t.week))
        XCTAssertFalse(week.contains("/"), "Date au format américain : \(week)")
        app.buttons["timesheet.previous"].tap()
        XCTAssertNotEqual(title.label, week)
        app.buttons["timesheet.next"].tap()
        XCTAssertEqual(title.label, week)
        keep(app, "\(t.code)-semaine")

        let preview = app.buttons["timesheet.preview"]
        reveal(preview, in: app)
        XCTAssertTrue(app.buttons["timesheet.share"].exists)
        preview.tap()
        XCTAssertTrue(app.navigationBars[t.preview].waitForExistence(timeout: 5))
        sleep(1)
        keep(app, "\(t.code)-apercu")
        app.navigationBars[t.preview].buttons[t.close].tap()

        app.swipeDown()
        app.buttons[t.month].firstMatch.tap()
        XCTAssertFalse(title.label.hasPrefix(t.week))
        app.buttons["CSV"].firstMatch.tap()
        let share = app.buttons["timesheet.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(preview.exists)
        keep(app, "\(t.code)-mois-csv")
    }

    private func launch(_ t: Texts, pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "-AppleLanguages", "(\(t.code))", "-AppleLocale", t.locale,
                               "-liveTimer.startDate", "0"]
            + (pro ? ["-WorkTimerDebugProUnlocked"] : [])
        app.launch()
        return app
    }

    private func openTimesheet(_ app: XCUIApplication, _ t: Texts) {
        app.tabBars.buttons[t.settings].tap()
        let export = app.buttons[t.export].firstMatch
        reveal(export, in: app)
        export.tap()
        let button = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", t.timesheet)).firstMatch
        _ = button.waitForExistence(timeout: 3)
        reveal(button, in: app)
        button.tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 8 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
