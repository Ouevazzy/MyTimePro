//
//  EntryCheckUITests.swift
//  WorkTimerUITests
//
//  Contrôle de saisie : rappel sur l'accueil, liste, saisie directe, jours
//  ignorés, et achat proposé sans Pro.
//

import XCTest

final class EntryCheckUITests: XCTestCase {
    private struct Texts {
        let code, locale, home, calendar, save, settings, features, check, ignore, close: String
    }

    private let french = Texts(code: "fr", locale: "fr_CH", home: "Accueil", calendar: "Calendrier",
        save: "Enregistrer", settings: "Réglages", features: "Fonctionnalités", check: "Contrôle de saisie",
        ignore: "Ignorer", close: "Fermer")
    private let english = Texts(code: "en", locale: "en_CH", home: "Home", calendar: "Calendar",
        save: "Save", settings: "Settings", features: "Features", check: "Entry Check",
        ignore: "Ignore", close: "Close")
    private let german = Texts(code: "de-CH", locale: "de_CH", home: "Übersicht", calendar: "Kalender",
        save: "Speichern", settings: "Einstellungen", features: "Funktionen", check: "Erfassungskontrolle",
        ignore: "Ignorieren", close: "Schliessen")

    override func setUp() { continueAfterFailure = false }

    func testFrench() throws { try check(french) }
    func testEnglish() throws { try check(english) }
    func testSwissGerman() throws { try check(german) }

    func testRequiresPro() {
        let app = launch(french, pro: false)
        XCTAssertFalse(app.buttons["home.entryCheck"].exists)
        openFromSettings(app, french)
        XCTAssertTrue(app.staticTexts["Passez à Pro"].waitForExistence(timeout: 5))
        keep(app, "fr-achat")
    }

    private func check(_ t: Texts) throws {
        let app = launch(t, pro: true)
        XCTAssertFalse(app.buttons["home.entryCheck"].exists, "Rien à vérifier sans aucune saisie")

        // Une saisie il y a une semaine : les jours travaillés suivants manquent.
        app.tabBars.buttons[t.calendar].tap()
        let weekAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -7, to: Date()))
        let cell = app.buttons["calendar-day-\(identity(weekAgo))"].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        var attempts = 0
        while !cell.isHittable && attempts < 4 {
            app.swipeDown(velocity: .slow)
            attempts += 1
        }
        cell.tap()
        app.buttons["calendar.add"].tap()
        app.buttons[t.save].firstMatch.tap()

        app.tabBars.buttons[t.home].tap()
        let card = app.buttons["home.entryCheck"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        keep(app, "\(t.code)-accueil")
        card.tap()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'entryCheck.2'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        let initial = rows.count
        XCTAssertGreaterThanOrEqual(initial, 4)
        keep(app, "\(t.code)-liste")

        // Compléter un jour l'enlève de la liste.
        rows.firstMatch.tap()
        let save = app.buttons[t.save].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        keep(app, "\(t.code)-saisie")
        save.tap()
        wait(for: [expectation(for: NSPredicate(format: "count == %d", initial - 1), evaluatedWith: rows)], timeout: 5)

        // Ignorer, puis réafficher.
        rows.firstMatch.swipeLeft()
        app.buttons[t.ignore].firstMatch.tap()
        wait(for: [expectation(for: NSPredicate(format: "count == %d", initial - 2), evaluatedWith: rows)], timeout: 5)
        let restore = app.buttons["entryCheck.restoreIgnored"]
        attempts = 0
        while !(restore.exists && restore.isHittable) && attempts < 4 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        keep(app, "\(t.code)-ignore")
        restore.tap()
        wait(for: [expectation(for: NSPredicate(format: "count == %d", initial - 1), evaluatedWith: rows)], timeout: 5)

        app.buttons[t.close].firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains(String(initial - 1)), card.label)
    }

    private func identity(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    private func launch(_ t: Texts, pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "-AppleLanguages", "(\(t.code))", "-AppleLocale", t.locale,
                               "-liveTimer.startDate", "0"] + (pro ? ["-WorkTimerDebugProUnlocked"] : [])
        app.launch()
        return app
    }

    private func openFromSettings(_ app: XCUIApplication, _ t: Texts) {
        app.tabBars.buttons[t.settings].tap()
        let features = app.buttons[t.features].firstMatch
        reveal(features, in: app)
        features.tap()
        let button = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", t.check)).firstMatch
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
