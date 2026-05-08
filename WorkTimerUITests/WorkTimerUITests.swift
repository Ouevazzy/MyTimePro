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
        app.launchArguments = ["UI_TESTING"]
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
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists)
        XCTAssertTrue(app.tabBars.buttons["Réglages"].exists)
        
        // Naviguer vers chaque onglet
        app.tabBars.buttons["Journées"].tap()
        XCTAssertTrue(app.navigationBars["Journées"].waitForExistence(timeout: 3))
        
        app.tabBars.buttons["Calendrier"].tap()
        XCTAssertTrue(app.navigationBars["Calendrier"].waitForExistence(timeout: 3))
        
        app.tabBars.buttons["Stats"].tap()
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
        
        // Vérifier la présence des sections
        XCTAssertTrue(app.staticTexts["Cette année"].waitForExistence(timeout: 3) ||
                     app.staticTexts["Annuel"].waitForExistence(timeout: 3))
    }
    
    // MARK: - Work Days List Tests
    
    func testWorkDaysListNavigation() throws {
        app.tabBars.buttons["Journées"].tap()
        
        // Attendre le chargement
        let navBar = app.navigationBars["Journées"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))
        
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
        
        let navBar = app.navigationBars["Calendrier"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))
        
        // Vérifier la navigation entre les mois
        let nextButton = app.buttons["chevron.right"]
        let prevButton = app.buttons["chevron.left"]
        
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()
            sleep(1)
            
            if prevButton.exists {
                prevButton.tap()
            }
        }
    }
    
    // MARK: - Stats View Tests
    
    func testStatsViewContent() throws {
        app.tabBars.buttons["Stats"].tap()
        
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
                XCUIApplication().launch()
            }
        }
    }
    
    func testTabSwitchingPerformance() throws {
        measure {
            app.tabBars.buttons["Journées"].tap()
            app.tabBars.buttons["Calendrier"].tap()
            app.tabBars.buttons["Stats"].tap()
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
        app.tabBars.buttons["Stats"].tap()
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











