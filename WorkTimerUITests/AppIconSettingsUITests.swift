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
        select("aurora", named: "Aurore", from: pickerRow, in: app)
        select("mint", named: "Menthe", from: pickerRow, in: app)
        select("paper", named: "Papier", from: pickerRow, in: app)
        select("timeCard", named: "Pointeuse", from: pickerRow, in: app)
        select("dusk", named: "Crépuscule", from: pickerRow, in: app)
        select("calendar", named: "Calendrier", from: pickerRow, in: app)

        app.terminate()
        app.launch()
        let relaunchedPickerRow = openDisplaySettings(in: app)
        XCTAssertEqual(relaunchedPickerRow.value as? String, "Calendrier")
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
        // La liste compte 12 icônes : les dernières n'apparaissent qu'après défilement.
        XCTAssertTrue(app.buttons["settings.appIcon.option.graphite"].waitForExistence(timeout: 5))
        for _ in 0..<6 where !(option.exists && option.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(option.isHittable)
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
