import XCTest

final class AppIconSettingsUITests: XCTestCase {
    func testAlternateIconsCanBeSelectedAndReset() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_CH"]
        app.launch()

        let pickerRow = openDisplaySettings(in: app)
        select("midnight", named: "Bleu nuit", from: pickerRow, in: app)
        select("amber", named: "Ambre", from: pickerRow, in: app)
        select("smokedGlass", named: "Sablier fumé", from: pickerRow, in: app)
        select("sapphire", named: "Chrono saphir", from: pickerRow, in: app)
        select("frosted", named: "Pointage givré", from: pickerRow, in: app)

        app.terminate()
        app.launch()
        let relaunchedPickerRow = openDisplaySettings(in: app)
        XCTAssertEqual(relaunchedPickerRow.value as? String, "Pointage givré")
        select("graphite", named: "Graphite", from: relaunchedPickerRow, in: app)
    }

    private func openDisplaySettings(in app: XCUIApplication) -> XCUIElement {
        let settings = app.tabBars.buttons["Réglages"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        let display = app.buttons["Affichage"].firstMatch
        XCTAssertTrue(display.waitForExistence(timeout: 5))
        display.tap()

        let pickerRow = app.buttons["settings.appIcon.open"]
        for _ in 0..<4 where !pickerRow.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(pickerRow.isHittable)
        return pickerRow
    }

    private func select(_ icon: String, named name: String, from row: XCUIElement, in app: XCUIApplication) {
        row.tap()
        let option = app.buttons["settings.appIcon.option.\(icon)"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()

        let confirmation = app.alerts.buttons["OK"].firstMatch
        if confirmation.waitForExistence(timeout: 3) {
            confirmation.tap()
        }

        let done = app.buttons["Terminé"]
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertEqual(row.value as? String, name)
    }
}
