//
//  WorkTimerUITests.swift
//  WorkTimerUITests
//
//  Tests automatisés de l'interface utilisateur
//

import XCTest

final class WorkTimerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Tab Navigation Tests
    
    func testTabBarNavigation() throws {
        // Vérifier que tous les onglets sont présents
        XCTAssertTrue(app.tabBars.buttons["Accueil"].exists)
        XCTAssertTrue(app.tabBars.buttons["Journées"].exists)
        XCTAssertTrue(app.tabBars.buttons["Calendrier"].exists)
        XCTAssertTrue(app.tabBars.buttons["Statistiques"].exists)
        XCTAssertTrue(app.tabBars.buttons["Réglages"].exists)
        
        // Naviguer vers chaque onglet
        app.tabBars.buttons["Journées"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["workdays.content"].waitForExistence(timeout: 3))
        
        app.tabBars.buttons["Calendrier"].tap()
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 3))
        
        app.tabBars.buttons["Statistiques"].tap()
        XCTAssertTrue(app.navigationBars["Statistiques"].waitForExistence(timeout: 3))
        
        app.tabBars.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 3))
        
        // Retour à l'accueil
        app.tabBars.buttons["Accueil"].tap()
    }
    
    // MARK: - Home View Tests
    
    func testHomeViewContent() throws {
        // Vérifier que la vue d'accueil charge correctement
        let homeNav = app.navigationBars.firstMatch
        XCTAssertTrue(homeNav.waitForExistence(timeout: 5))
        
        XCTAssertTrue(app.descendants(matching: .any)["home.content"].waitForExistence(timeout: 3))
    }
    
    // MARK: - Work Days List Tests
    
    func testWorkDaysListNavigation() throws {
        app.tabBars.buttons["Journées"].tap()
        
        // Attendre le chargement
        XCTAssertTrue(app.descendants(matching: .any)["workdays.content"].waitForExistence(timeout: 5))
        
        // Vérifier le bouton d'ajout
        let addButton = app.navigationBars.buttons["plus"]
        if addButton.exists {
            XCTAssertTrue(addButton.isEnabled)
        }
    }
    
    func testAddWorkDayFlow() throws {
        app.tabBars.buttons["Journées"].tap()
        
        // Attendre le chargement
        sleep(2)
        
        // Taper sur le bouton d'ajout
        let addButton = app.navigationBars.buttons["plus"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            
            // Vérifier que la vue d'ajout s'ouvre
            let saveButton = app.buttons["Enregistrer"]
            XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
            
            // Fermer sans sauvegarder
            if app.buttons["Annuler"].exists {
                app.buttons["Annuler"].tap()
            }
        }
    }
    
    // MARK: - Calendar View Tests
    
    func testCalendarNavigation() throws {
        app.tabBars.buttons["Calendrier"].tap()
        
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 5))
        
        XCTAssertTrue(app.buttons["calendar.today"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["calendar.add"].exists)

        let monthAttachment = XCTAttachment(screenshot: app.screenshot())
        monthAttachment.name = "CalendarMonth"
        monthAttachment.lifetime = .keepAlways
        add(monthAttachment)

        let yearButton = app.buttons["calendar.year-overview"]
        XCTAssertTrue(yearButton.waitForExistence(timeout: 3))
        yearButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["calendar.year-view"].waitForExistence(timeout: 3))

        let yearAttachment = XCTAttachment(screenshot: app.screenshot())
        yearAttachment.name = "CalendarYear"
        yearAttachment.lifetime = .keepAlways
        add(yearAttachment)

        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let currentMonth = String(
            format: "calendar-month-%04d-%02d",
            components.year ?? 0,
            components.month ?? 0
        )
        XCTAssertTrue(app.buttons[currentMonth].waitForExistence(timeout: 3))
        app.buttons[currentMonth].tap()

        XCTAssertTrue(app.buttons["calendar.year-overview"].waitForExistence(timeout: 3))
    }

    func testCalendarDateSelectionStaysInMonth() throws {
        app.tabBars.buttons["Calendrier"].tap()
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 5))

        let today = Date()
        let dayOffset = Calendar.current.component(.day, from: today) == 1 ? 1 : -1
        let date = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: dayOffset, to: today))
        let dateCell = app.buttons[calendarDayIdentifier(for: date)]
        XCTAssertTrue(dateCell.waitForExistence(timeout: 3))
        dateCell.tap()

        let selectedCell = app.buttons
            .containing(.button, identifier: calendarDayIdentifier(for: date))
            .matching(NSPredicate(format: "isSelected == true"))
            .firstMatch
        XCTAssertTrue(selectedCell.waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["calendar.day-view"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["calendar.timeline"].exists)
        XCTAssertTrue(app.buttons["calendar.year-overview"].exists)
        XCTAssertTrue(app.buttons["calendar.today"].exists)
        XCTAssertFalse(app.buttons["Enregistrer"].exists)

        let preview = app.descendants(matching: .any)["calendar.selection-preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        let previewDate = app.staticTexts["calendar.preview.date"]
        let dateStyle = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.wide)
            .locale(Locale(identifier: "fr_FR"))
        XCTAssertEqual(previewDate.label, date.formatted(dateStyle))
        XCTAssertTrue(app.staticTexts["calendar.preview.empty"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "CalendarDateSelection"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["calendar.today"].tap()
        XCTAssertEqual(previewDate.label, today.formatted(dateStyle))
    }

    func testCalendarVisibleViewModes() throws {
        app.tabBars.buttons["Calendrier"].tap()
        let modes = app.segmentedControls["calendar.view-selector"]
        XCTAssertTrue(modes.waitForExistence(timeout: 5))

        modes.buttons["Jour"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.day-view"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["calendar.selection-preview"].exists)

        modes.buttons["Année"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.year-view"].waitForExistence(timeout: 3))

        modes.buttons["Mois"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.selection-preview"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["calendar.day-view"].exists)
    }

    func testCalendarPreviewForMultipleEntries() throws {
        app.tabBars.buttons["Calendrier"].tap()
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 5))

        for _ in 0..<2 {
            app.buttons["calendar.add"].tap()
            let save = app.buttons["Enregistrer"]
            XCTAssertTrue(save.waitForExistence(timeout: 3))
            XCTAssertTrue(save.isEnabled)
            save.tap()
            XCTAssertTrue(save.waitForNonExistence(timeout: 3))
        }

        XCTAssertTrue(app.staticTexts["2 entrées"].waitForExistence(timeout: 3))
        let balance = app.staticTexts["calendar.preview.balance"]
        XCTAssertTrue(balance.exists)
        let initialBalance = balance.label

        let today = Date()
        let offset = Calendar.current.component(.day, from: today) == 1 ? 1 : -1
        let otherDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: today))
        app.buttons[calendarDayIdentifier(for: otherDate)].tap()
        XCTAssertTrue(app.staticTexts["calendar.preview.empty"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Enregistrer"].exists)

        app.buttons[calendarDayIdentifier(for: today)].tap()
        XCTAssertTrue(app.staticTexts["2 entrées"].waitForExistence(timeout: 3))
        XCTAssertEqual(balance.label, initialBalance)
        XCTAssertFalse(app.buttons["Enregistrer"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["calendar.day-view"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "CalendarMultipleEntriesSelection"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func calendarDayIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "calendar-day-%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
    
    // MARK: - Stats View Tests
    
    func testStatsViewContent() throws {
        app.tabBars.buttons["Statistiques"].tap()
        
        let navBar = app.navigationBars["Statistiques"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))
        
        // Vérifier la navigation entre les années
        let nextYearButton = app.buttons["chevron.right"]
        if nextYearButton.waitForExistence(timeout: 3) {
            // Navigation OK
        }
    }
    
    // MARK: - Settings View Tests
    
    func testSettingsNavigation() throws {
        app.tabBars.buttons["Réglages"].tap()
        
        let navBar = app.navigationBars["Réglages"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))
        
        // Vérifier la présence des sections principales
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists)
    }
    
    func testNotificationSettings() throws {
        app.tabBars.buttons["Réglages"].tap()
        sleep(2)
        
        // Chercher le bouton des notifications
        let notificationButton = app.buttons["Notifications"]
        if notificationButton.waitForExistence(timeout: 3) {
            notificationButton.tap()
            
            // Vérifier la vue des notifications
            let notificationNav = app.navigationBars["Notifications"]
            XCTAssertTrue(notificationNav.waitForExistence(timeout: 3))
            
            // Retour
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
    
    // MARK: - PDF Export Tests
    
    func testPDFExportFlow() throws {
        app.tabBars.buttons["Réglages"].tap()
        sleep(2)
        
        // Chercher le bouton d'export PDF
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        
        let pdfButton = app.buttons["Générer un rapport PDF"]
        if pdfButton.waitForExistence(timeout: 3) {
            pdfButton.tap()
            
            // Vérifier l'ouverture de la vue d'export
            sleep(2)
            
            // Fermer si possible
            if app.buttons["Fermer"].exists {
                app.buttons["Fermer"].tap()
            } else if app.buttons["Annuler"].exists {
                app.buttons["Annuler"].tap()
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Vérifier que les onglets ont des labels d'accessibilité
        let homeTab = app.tabBars.buttons["Accueil"]
        XCTAssertTrue(homeTab.exists)
        
        let daysTab = app.tabBars.buttons["Journées"]
        XCTAssertTrue(daysTab.exists)
    }
    
    func testVoiceOverNavigation() throws {
        // Simuler la navigation VoiceOver en vérifiant l'accessibilité des éléments
        app.tabBars.buttons["Journées"].tap()
        sleep(2)
        
        // Vérifier que les éléments principaux sont accessibles
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.isAccessibilityElement || navBar.exists)
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let measuredApp = XCUIApplication()
                measuredApp.launchArguments = ["UI_TESTING", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
                measuredApp.launch()
            }
        }
    }
    
    func testTabSwitchingPerformance() throws {
        measure {
            app.tabBars.buttons["Journées"].tap()
            app.tabBars.buttons["Calendrier"].tap()
            app.tabBars.buttons["Statistiques"].tap()
            app.tabBars.buttons["Réglages"].tap()
            app.tabBars.buttons["Accueil"].tap()
        }
    }
    
    // MARK: - Scroll Tests
    
    func testScrollingInSettings() throws {
        app.tabBars.buttons["Réglages"].tap()
        sleep(2)
        
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists)
        
        // Scroll down
        scrollView.swipeUp()
        sleep(1)
        
        // Scroll up
        scrollView.swipeDown()
    }
    
    // MARK: - Interaction Tests
    
    func testToggleInteraction() throws {
        app.tabBars.buttons["Réglages"].tap()
        sleep(2)
        
        // Chercher un toggle (heures décimales par exemple)
        let toggles = app.switches
        if toggles.count > 0 {
            let firstToggle = toggles.element(boundBy: 0)
            if firstToggle.exists && firstToggle.isEnabled {
                let initialValue = firstToggle.value as? String
                firstToggle.tap()
                sleep(1)
                
                // Remettre la valeur initiale
                if firstToggle.value as? String != initialValue {
                    firstToggle.tap()
                }
            }
        }
    }
}

// MARK: - Snapshot Tests

extension WorkTimerUITests {
    
    func testTakeScreenshots() throws {
        // Home
        app.tabBars.buttons["Accueil"].tap()
        sleep(2)
        let homeScreenshot = app.screenshot()
        let homeAttachment = XCTAttachment(screenshot: homeScreenshot)
        homeAttachment.name = "Home"
        homeAttachment.lifetime = .keepAlways
        add(homeAttachment)
        
        // Work Days
        app.tabBars.buttons["Journées"].tap()
        sleep(2)
        let daysScreenshot = app.screenshot()
        let daysAttachment = XCTAttachment(screenshot: daysScreenshot)
        daysAttachment.name = "WorkDays"
        daysAttachment.lifetime = .keepAlways
        add(daysAttachment)
        
        // Calendar
        app.tabBars.buttons["Calendrier"].tap()
        sleep(2)
        let calendarScreenshot = app.screenshot()
        let calendarAttachment = XCTAttachment(screenshot: calendarScreenshot)
        calendarAttachment.name = "Calendar"
        calendarAttachment.lifetime = .keepAlways
        add(calendarAttachment)
        
        // Stats
        app.tabBars.buttons["Statistiques"].tap()
        sleep(2)
        let statsScreenshot = app.screenshot()
        let statsAttachment = XCTAttachment(screenshot: statsScreenshot)
        statsAttachment.name = "Stats"
        statsAttachment.lifetime = .keepAlways
        add(statsAttachment)
        
        // Settings
        app.tabBars.buttons["Réglages"].tap()
        sleep(2)
        let settingsScreenshot = app.screenshot()
        let settingsAttachment = XCTAttachment(screenshot: settingsScreenshot)
        settingsAttachment.name = "Settings"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)
    }
}
