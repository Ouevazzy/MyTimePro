//
//  StoreKitTestSupport.swift
//  WorkTimerUITests
//
//  Environnement d'achat local partagé par les tests d'interface. Les achats
//  de test restent sur le simulateur d'une série à l'autre : chaque test qui
//  dépend de l'état Pro ou de l'essai part donc d'un environnement vidé.
//

import StoreKitTest
import XCTest

enum StoreKitTestSupport {
    /// Session sur Products.storekit, sans achat, boutique Suisse.
    static func cleanSession(locale: String = "fr_CH") throws -> SKTestSession {
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

    /// Après un achat d'abonnement effacé, le simulateur met quelques secondes à
    /// reproposer l'essai. Attend sur l'écran d'achat ouvert que le bouton
    /// l'annonce de nouveau, pour ne pas fausser le test suivant.
    @MainActor
    static func waitForTrialAgain(in app: XCUIApplication, trialLabel: String) {
        let purchase = app.buttons["paywall.purchase"]
        for _ in 0..<15 where purchase.label != trialLabel {
            // L'app relit l'éligibilité en revenant au premier plan.
            XCUIDevice.shared.press(.home)
            sleep(2)
            app.activate()
            _ = purchase.waitForExistence(timeout: 3)
        }
        XCTAssertEqual(purchase.label, trialLabel, "L'essai n'est pas revenu après le ménage")
    }
}
