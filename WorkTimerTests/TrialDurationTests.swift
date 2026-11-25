import Foundation
import StoreKit
import Testing
@testable import WorkTimer

@MainActor
@Suite("Essai gratuit : durée affichée")
struct TrialDurationTests {
    /// Le français sépare le nombre et l'unité par une espace insécable.
    private func duration(_ value: Int, _ unit: Product.SubscriptionPeriod.Unit, _ language: String) -> String? {
        StoreManager.duration(value: value, unit: unit, locale: Locale(identifier: language))?
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test(arguments: [("fr", "14 jours"), ("en", "14 days"), ("de", "14 Tage"), ("de-CH", "14 Tage")])
    func twoWeeks(language: String, expected: String) {
        #expect(duration(2, .week, language) == expected)
        #expect(duration(14, .day, language) == expected)
    }

    @Test func oneWeekAndMonth() {
        #expect(duration(1, .week, "fr") == "7 jours")
        #expect(duration(1, .month, "fr") == "1 mois")
    }
}
