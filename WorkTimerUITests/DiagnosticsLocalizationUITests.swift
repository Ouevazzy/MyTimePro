//
//  DiagnosticsLocalizationUITests.swift
//  WorkTimerUITests
//
//  L'écran Diagnostic s'affiche dans la langue de l'app (ici l'anglais).
//

import XCTest

final class DiagnosticsLocalizationUITests: XCTestCase {
    func testDiagnosticsScreenIsInEnglish() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TESTING", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-liveTimer.startDate", "0"
        ]
        app.launch()

        app.tabBars.buttons["Settings"].tap()

        let diagnostics = app.buttons["Calculation Diagnostics"].firstMatch
        if !diagnostics.waitForExistence(timeout: 2) {
            let about = app.buttons["About"].firstMatch
            var attempts = 0
            while !about.isHittable && attempts < 5 {
                app.swipeUp()
                attempts += 1
            }
            about.tap()
        }
        var attempts = 0
        while !diagnostics.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        diagnostics.tap()

        XCTAssertTrue(app.navigationBars["Diagnostics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Total entries"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Close"].exists)

        let french = ["Entrées totales", "Fermer", "Année", "Jours travaillés", "Aucun doublon"]
        for text in french {
            XCTAssertFalse(app.staticTexts[text].exists, "Texte français visible : \(text)")
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
