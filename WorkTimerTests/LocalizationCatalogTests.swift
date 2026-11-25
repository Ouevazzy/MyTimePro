//
//  LocalizationCatalogTests.swift
//  WorkTimerTests
//
//  Chaque langue livrée contient tous les textes, avec les mêmes arguments,
//  et l'allemand suisse respecte l'orthographe suisse (pas de « ß »).
//

import Foundation
import Testing
@testable import WorkTimer

@Suite("Traductions")
struct LocalizationCatalogTests {
    private static let languages = ["fr", "en", "de", "de-CH"]

    private func strings(_ table: String, _ language: String) throws -> [String: String] {
        let url = try #require(Bundle.main.url(
            forResource: table, withExtension: "strings", subdirectory: nil, localization: language))
        return try #require(NSDictionary(contentsOf: url) as? [String: String])
    }

    private func arguments(in value: String) -> [String] {
        let pattern = /%(?:\d+\$)?[-+ 0]*\d*(?:\.\d+)?(?:l{0,2}[du]|@|f|%)|\$\{\w+\}/
        return value.matches(of: pattern).map { String($0.output) }.sorted()
    }

    @Test("Langue complète", arguments: languages, ["Localizable", "AppShortcuts", "InfoPlist"])
    func languageIsComplete(language: String, table: String) throws {
        let reference = try strings(table, "fr")
        let translated = try strings(table, language)
        #expect(!reference.isEmpty)
        #expect(Set(reference.keys) == Set(translated.keys))
        for (key, value) in reference {
            let other = translated[key] ?? ""
            #expect(!other.isEmpty, "Vide : \(key)")
            #expect(arguments(in: value) == arguments(in: other), "Arguments différents : \(key)")
        }
    }

    @Test("Allemand suisse : pas de ß, vocabulaire suisse")
    func swissGerman() throws {
        for table in ["Localizable", "AppShortcuts", "InfoPlist"] {
            for (key, value) in try strings(table, "de-CH") {
                #expect(!value.contains("ß"), "\(key)")
                #expect(!value.contains("Urlaub"), "\(key)")
            }
        }
        #expect(try strings("Localizable", "de-CH")["workDayType.vacation"] == "Ferien")
    }

    @Test("Pluriel de la suppression", arguments: [
        ("fr", "1 journée ?", "3 journées ?"), ("en", "1 day?", "3 days?"),
        ("de", "1 Tag ", "3 Tage "), ("de-CH", "1 Tag ", "3 Tage ")
    ])
    func deletionPlural(language: String, one: String, other: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: "delete.confirm.message", value: nil, table: nil)
        let locale = Locale(identifier: language)
        #expect(String(format: format, locale: locale, 1).contains(one))
        #expect(String(format: format, locale: locale, 3).contains(other))
    }
}
