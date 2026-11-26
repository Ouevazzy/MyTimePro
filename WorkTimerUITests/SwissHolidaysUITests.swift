//
//  SwissHolidaysUITests.swift
//  WorkTimerUITests
//
//  Choix du canton, liste, ajout des jours fériés, et achat proposé sans Pro.
//

import XCTest

final class SwissHolidaysUITests: XCTestCase {
    private struct Texts {
        let code, locale, settings, features, holidays, valais, neuchatel, none, add, ascension: String
    }

    private let french = Texts(code: "fr", locale: "fr_CH", settings: "Réglages", features: "Fonctionnalités",
        holidays: "Jours fériés suisses", valais: "Valais", neuchatel: "Neuchâtel", none: "Aucun",
        add: "Ajouter", ascension: "Ascension")
    private let german = Texts(code: "de-CH", locale: "de_CH", settings: "Einstellungen", features: "Funktionen",
        holidays: "Schweizer Feiertage", valais: "Wallis", neuchatel: "Neuenburg", none: "Keiner",
        add: "Hinzufügen", ascension: "Auffahrt")

    override func setUp() { continueAfterFailure = false }

    func testFrench() { checkAdding(french) }
    func testSwissGerman() { checkAdding(german) }

    func testRequiresPro() throws {
        // Un achat de test resté d'une série précédente rendrait l'app Pro.
        let session = try StoreKitTestSupport.cleanSession()
        defer { session.clearTransactions() }
        let app = launch(french, pro: false)
        openHolidays(app, french)
        XCTAssertTrue(app.staticTexts["Passez à Pro"].waitForExistence(timeout: 5))
        let feature = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Jours fériés de votre canton")).firstMatch
        XCTAssertTrue(feature.exists)
        XCTAssertFalse(app.descendants(matching: .any)["swissHolidays.canton"].exists)
        keep(app, "fr-achat")
    }

    private func checkAdding(_ t: Texts) {
        let app = launch(t, pro: true)
        openHolidays(app, t)
        choose(app, t.neuchatel)
        XCTAssertTrue(app.descendants(matching: .any)["swissHolidays.region"].firstMatch.waitForExistence(timeout: 3))
        keep(app, "\(t.code)-neuchatel")

        choose(app, t.valais)
        XCTAssertFalse(app.descendants(matching: .any)["swissHolidays.region"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", t.ascension))
            .firstMatch.waitForExistence(timeout: 3))
        keep(app, "\(t.code)-valais")

        let addAll = app.buttons["swissHolidays.addAll"].firstMatch
        reveal(addAll, in: app)
        XCTAssertTrue(addAll.exists)
        addAll.tap()
        let confirm = app.alerts.buttons[t.add]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        keep(app, "\(t.code)-confirmation")
        confirm.tap()
        XCTAssertTrue(addAll.waitForNonExistence(timeout: 5))
        keep(app, "\(t.code)-ajoutes")

        // Le choix est enregistré dans iCloud : remettre « aucun ».
        app.swipeDown()
        app.swipeDown()
        choose(app, t.none)
        XCTAssertFalse(addAll.exists)
    }

    private func launch(_ t: Texts, pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "-AppleLanguages", "(\(t.code))", "-AppleLocale", t.locale,
                               "-liveTimer.startDate", "0"] + (pro ? ["-WorkTimerDebugProUnlocked"] : [])
        app.launch()
        return app
    }

    private func openHolidays(_ app: XCUIApplication, _ t: Texts) {
        app.tabBars.buttons[t.settings].tap()
        let features = app.buttons[t.features].firstMatch
        reveal(features, in: app)
        features.tap()
        let button = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", t.holidays)).firstMatch
        _ = button.waitForExistence(timeout: 3)
        reveal(button, in: app)
        button.tap()
    }

    private func choose(_ app: XCUIApplication, _ name: String) {
        let picker = app.descendants(matching: .any)["swissHolidays.canton"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let option = app.buttons[name].firstMatch
        _ = option.waitForExistence(timeout: 3)
        reveal(option, in: app)
        option.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
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
