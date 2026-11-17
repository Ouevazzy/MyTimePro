//
//  LiveTimerSettingsUITests.swift
//  WorkTimerUITests
//
//  Vérifie de bout en bout le masquage de la carte chrono depuis les réglages.
//

import XCTest

final class LiveTimerSettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // `-liveTimer.startDate 0` ignore une session persistée sur le simulateur.
        app.launchArguments = [
            "UI_TESTING", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
            "-liveTimer.startDate", "0"
        ]
        app.launch()
    }

    func testShowTimerToggleHidesHomeCard() throws {
        // Le réglage est conservé entre deux lancements : on part d'un état connu.
        setShowTimer(true)
        app.tabBars.buttons["Accueil"].tap()
        let clockIn = app.buttons["timer.clockIn"]
        XCTAssertTrue(clockIn.waitForExistence(timeout: 8), "La carte chrono doit être visible au départ")

        setShowTimer(false)
        app.tabBars.buttons["Accueil"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["home.content"].waitForExistence(timeout: 3))
        XCTAssertFalse(clockIn.waitForExistence(timeout: 2), "La carte chrono doit être masquée")

        setShowTimer(true)
        app.tabBars.buttons["Accueil"].tap()
        XCTAssertTrue(clockIn.waitForExistence(timeout: 5), "La carte chrono doit réapparaître")
    }

    private func setShowTimer(_ enabled: Bool) {
        app.tabBars.buttons["Réglages"].tap()

        let toggle = app.switches["settings.display.showTimer"]
        if !toggle.waitForExistence(timeout: 1) {
            let section = app.buttons["Affichage"].firstMatch
            XCTAssertTrue(section.waitForExistence(timeout: 5))
            section.tap()
            XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        }

        var attempts = 0
        while !toggle.isHittable && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }

        let expected = enabled ? "1" : "0"
        if toggle.value as? String != expected {
            toggle.switches.firstMatch.tap()
        }
        XCTAssertEqual(toggle.value as? String, expected)
    }
}
