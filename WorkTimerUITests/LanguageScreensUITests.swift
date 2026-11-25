//
//  LanguageScreensUITests.swift
//  WorkTimerUITests
//
//  Parcourt les cinq onglets et l'écran d'achat dans chaque langue et garde
//  une capture de chaque écran, puis vérifie sur les écrans secondaires qu'aucun
//  texte français ni clé technique ne reste visible. Les prix viennent du StoreKit local, boutique Suisse.
//

import StoreKitTest
import XCTest

final class LanguageScreensUITests: XCTestCase {
    private struct Language {
        let code: String
        let locale: String
        let tabs: [String]
        let subscription: String
        let upgrade: String
        let headline: String
        let plans: [String]
        let restore: String
        let trial: String
        let trialDays: String
        let subscribe: String
    }

    func testFrench() throws {
        try check(Language(code: "fr", locale: "fr_CH",
            tabs: ["Accueil", "Journées", "Calendrier", "Statistiques", "Réglages"],
            subscription: "Abonnement", upgrade: "Passer à Pro", headline: "Passez à Pro",
            plans: ["Mensuel", "Annuel", "À vie"], restore: "Restaurer les achats",
            trial: "Essayer gratuitement", trialDays: "14 jours", subscribe: "S'abonner"))
    }

    func testEnglish() throws {
        try check(Language(code: "en", locale: "en_CH",
            tabs: ["Home", "Work Days", "Calendar", "Statistics", "Settings"],
            subscription: "Subscription", upgrade: "Upgrade to Pro", headline: "Go Pro",
            plans: ["Monthly", "Annual", "Lifetime"], restore: "Restore Purchases",
            trial: "Try for Free", trialDays: "14 days", subscribe: "Subscribe"))
    }

    /// Un abonnement qui expire pendant que l'app est ouverte retire Pro au retour
    /// au premier plan, et l'essai n'est plus proposé.
    func testExpiredSubscriptionLosesProAndTrial() async throws {
        continueAfterFailure = false
        let session = try makeSession(locale: "fr_CH")
        let transaction = try await session.buyProduct(identifier: "com.worktimer.pro.annual")
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        let app = await MainActor.run { () -> XCUIApplication in
            let app = XCUIApplication()
            app.launchArguments = ["UI_TESTING", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_CH", "-liveTimer.startDate", "0"]
            app.launch()
            app.tabBars.buttons["Réglages"].tap()
            app.buttons["Abonnement"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["PRO"].waitForExistence(timeout: 5), "Pro attendu pendant l'abonnement")
            return app
        }
        try session.expireSubscription(productIdentifier: "com.worktimer.pro.annual")
        await MainActor.run {
            let upgrade = app.buttons["Passer à Pro"].firstMatch
            // Le StoreKit de test signale l'expiration avec un délai variable.
            for _ in 0..<8 where !upgrade.exists {
                XCUIDevice.shared.press(.home)
                sleep(3)
                app.activate()
                _ = upgrade.waitForExistence(timeout: 3)
            }
            XCTAssertTrue(upgrade.exists, "Pro toujours actif après expiration")
            upgrade.tap()
            let purchase = app.buttons["paywall.purchase"]
            XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Annuel'")).firstMatch.waitForExistence(timeout: 10))
            XCTAssertTrue(purchase.label.hasPrefix("S'abonner"), purchase.label)
            XCTAssertFalse(app.staticTexts["paywall.trial.terms"].exists)
            keep(app, "fr-sans-essai")
        }
        session.clearTransactions()
    }

    func testSwissGerman() throws {
        try check(Language(code: "de-CH", locale: "de_CH",
            tabs: ["Übersicht", "Tage", "Kalender", "Statistik", "Einstellungen"],
            subscription: "Abonnement", upgrade: "Zu Pro wechseln", headline: "Pro werden",
            plans: ["Monatlich", "Jährlich", "Lebenslang"], restore: "Käufe wiederherstellen",
            trial: "Gratis testen", trialDays: "14 Tage", subscribe: "Abonnieren"))
    }

    func testSecondaryScreensSwissGerman() throws { try checkSecondaryScreens("de-CH", "de_CH") }
    func testSecondaryScreensEnglish() throws { try checkSecondaryScreens("en", "en_CH") }

    /// Textes du catalogue, lus dans les sources : clé → langue → valeur.
    private lazy var catalog: [String: [String: String]] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("WorkTimer/Localizable.xcstrings")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: [String: Any]] else { return [:] }
        return strings.compactMapValues { entry in
            (entry["localizations"] as? [String: [String: Any]])?
                .compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
        }
    }()

    private func checkSecondaryScreens(_ code: String, _ locale: String) throws {
        continueAfterFailure = false
        func t(_ key: String) -> String { catalog[key]?[code] ?? key }
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TESTING", "-AppleLanguages", "(\(code))", "-AppleLocale", locale,
            "-liveTimer.startDate", "0", "-WorkTimerDebugProUnlocked"
        ]
        app.launch()

        func tap(_ label: String) {
            let button = app.buttons.matching(NSPredicate(
                format: "label == %@ OR label BEGINSWITH %@", label, label + ",")).firstMatch
            var attempts = 0
            while !(button.exists && button.isHittable) && attempts < 8 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(button.exists, "Bouton absent : \(label)")
            button.tap()
        }
        func inspect(_ name: String) {
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)
            keep(app, "\(code)-\(name.replacingOccurrences(of: ".", with: "-"))")
            assertTranslated(app, code, name)
        }
        func relaunchInSettings() {
            app.terminate()
            app.launch()
            app.tabBars.buttons[t("navigation.settings")].tap()
        }

        app.tabBars.buttons[t("navigation.calendar")].tap()
        app.buttons["calendar.add"].tap()
        inspect("saisie")
        app.buttons[t("action.save")].firstMatch.tap()
        for tab in ["navigation.workDays", "navigation.calendar", "navigation.stats", "navigation.home"] {
            app.tabBars.buttons[t(tab)].tap()
            inspect("avec-saisie-\(tab)")
        }
        app.tabBars.buttons[t("navigation.settings")].tap()
        tap(t("settings.features.title"))
        tap(t("settings.charts"))
        for chart in ["charts.type.weekly", "charts.type.monthly", "charts.type.distribution"] {
            app.buttons[t(chart)].firstMatch.tap()
            inspect(chart)
        }
        relaunchInSettings()
        app.tabBars.buttons[t("navigation.home")].tap()
        tap(t("action.viewDetails"))
        inspect("conges")
        relaunchInSettings()
        tap(t("settings.about.title"))
        tap(t("settings.diagnostics"))
        inspect("diagnostic")
        relaunchInSettings()
        tap(t("settings.privacy.title"))
        tap(t("settings.privacy.icloud"))
        inspect("icloud")

        let sections = [
            "settings.workTime.title", "settings.display.title", "settings.features.title",
            "settings.privacy.title", "settings.export.title", "settings.about.title", "settings.reset"
        ]
        for section in sections {
            relaunchInSettings()
            tap(t(section))
            app.swipeUp()
            inspect(section)
        }
        for feature in ["settings.notifications", "settings.charts", "settings.siri"] {
            relaunchInSettings()
            tap(t("settings.features.title"))
            tap(t(feature))
            inspect(feature)
        }
        for export in ["settings.export.monthly", "settings.export.annual"] {
            relaunchInSettings()
            tap(t("settings.export.title"))
            tap(t(export))
            inspect(export)
        }
    }

    /// Un texte visible identique au français, alors que la langue a une autre
    /// traduction, ou ressemblant à une clé, signale un oubli.
    private func assertTranslated(_ app: XCUIApplication, _ code: String, _ screen: String) {
        let own = Set(catalog.values.compactMap { $0[code] })
        let french = Set(catalog.values.compactMap { $0["fr"] }).subtracting(own)
        let labels = (app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex
            + app.switches.allElementsBoundByIndex).map(\.label)
        for label in Set(labels) {
            XCTAssertFalse(french.contains(label), "\(screen) : texte français « \(label) »")
            XCTAssertNil(catalog[label].flatMap { $0["fr"] }, "\(screen) : clé non traduite \(label)")
            let words = Set(label.lowercased().split { !$0.isLetter }.map(String.init))
            for word in ["le", "les", "des", "une", "vos", "votre", "heures", "jours", "pour", "avec", "travailler"] {
                XCTAssertFalse(words.contains(word), "\(screen) : « \(label) »")
            }
        }
    }

    private func check(_ language: Language) throws {
        continueAfterFailure = false
        let session = try makeSession(locale: language.locale)
        defer { session.clearTransactions() }

        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TESTING", "-AppleLanguages", "(\(language.code))", "-AppleLocale", language.locale,
            "-liveTimer.startDate", "0"
        ]
        app.launch()

        for (index, tab) in language.tabs.enumerated() {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Onglet absent : \(tab)")
            button.tap()
            keep(app, "\(language.code)-\(index + 1)")
        }

        let upgrade = app.buttons[language.upgrade].firstMatch
        if !upgrade.waitForExistence(timeout: 1) {
            app.buttons[language.subscription].firstMatch.tap()
        }
        XCTAssertTrue(upgrade.waitForExistence(timeout: 3))
        keep(app, "\(language.code)-6-abonnement")
        upgrade.tap()

        XCTAssertTrue(app.staticTexts[language.headline].waitForExistence(timeout: 5))
        for plan in language.plans {
            let card = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", plan)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10), "Offre absente : \(plan)")
            XCTAssertTrue(card.label.contains("CHF"), "Prix sans CHF : \(card.label)")
        }
        // L'annuel est choisi par défaut : essai annoncé, avec le prix qui suit.
        let purchase = app.buttons["paywall.purchase"]
        XCTAssertEqual(purchase.label, language.trial)
        let terms = app.staticTexts["paywall.trial.terms"]
        let termsLabel = terms.label.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        XCTAssertTrue(termsLabel.hasPrefix(language.trialDays), terms.label)
        XCTAssertTrue(terms.label.contains("CHF"), terms.label)
        keep(app, "\(language.code)-7-achat-haut")
        // Le mensuel n'a pas d'essai : prix normal.
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", language.plans[0])).firstMatch.tap()
        XCTAssertTrue(purchase.label.hasPrefix(language.subscribe), purchase.label)
        XCTAssertFalse(terms.exists)
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", language.plans[1])).firstMatch.tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons[language.restore].firstMatch.waitForExistence(timeout: 3))
        keep(app, "\(language.code)-8-achat-bas")
    }

    private func makeSession(locale: String) throws -> SKTestSession {
        let configuration = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("WorkTimer/Products.storekit")
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        session.storefront = "CHE"
        session.locale = Locale(identifier: locale)
        return session
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
