//
//  SwissHolidaysTests.swift
//  WorkTimerTests
//
//  Le tableau ci-dessous est recopié du tableau du SECO (état au 12.12.2024),
//  indépendamment du code, puis comparé à lui case par case.
//

import Foundation
import SwiftData
import Testing
@testable import WorkTimer

@Suite("Jours fériés suisses")
struct SwissHolidaysTests {
    private static let all = "AG AI AR BE BL BS FR GE GL GR JU LU NE NW OW SG SH SO SZ TG TI UR VD VS ZG ZH"

    static let secoTable: [(SwissHoliday, String)] = [
        (.newYear, all),
        (.berchtold, "AG BE FR NE TG VD"),
        (.epiphany, "TI"),
        (.neuchatelRepublic, "NE"),
        (.saintJoseph, "SZ VS"),
        (.fahrtsfest, "GL"),
        (.goodFriday, "AG AI AR BE BL BS FR GE GL GR JU LU NE NW OW SG SH SO SZ TG UR VD ZG ZH"),
        (.easterMonday, "AG AI AR BE BL BS FR GE GL GR JU SG SH TG TI VD ZH"),
        (.labourDay, "BL BS JU NE SH SO ZH"),
        (.ascension, all),
        (.whitMonday, "AG AI AR BE BL BS FR GE GR JU SG SH TG VD ZH"),
        (.corpusChristi, "AG AI FR JU LU NE NW OW SO SZ UR VS ZG"),
        (.nationalDay, all),
        (.assumption, "AG FR LU NW OW SO SZ TI UR VS ZG"),
        (.genevaFast, "GE"),
        (.federalFastMonday, "VD"),
        (.allSaints, "AG FR GL LU NW OW SG SO SZ TI UR VS ZG"),
        (.immaculateConception, "AG FR NW OW UR VS ZG"),
        (.christmas, all),
        (.saintStephen, "AG AI AR BE BL BS FR GL GR LU NE SG SH TG TI ZH"),
        (.genevaRestoration, "GE")
    ]

    /// 2022–2033 couvre les jours qui ne sont fériés que certaines années.
    private func cantons(observing holiday: SwissHoliday) -> Set<String> {
        Set(SwissHolidayRegion.allCases.filter { region in
            (2022...2033).contains { year in region.holidays(in: year).contains { $0.holiday == holiday } }
        }.map(\.canton.rawValue))
    }

    private func text(_ date: Date?) -> String {
        guard let date else { return "-" }
        let c = SwissHolidayCalendar.gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func has(_ region: SwissHolidayRegion, _ holiday: SwissHoliday, _ year: Int) -> Bool {
        region.holidays(in: year).contains { $0.holiday == holiday }
    }

    @Test("Le tableau du SECO est respecté", arguments: SwissHoliday.allCases)
    func matchesSecoTable(holiday: SwissHoliday) throws {
        let row = try #require(Self.secoTable.first { $0.0 == holiday })
        #expect(cantons(observing: holiday) == Set(row.1.split(separator: " ").map(String.init)))
    }

    @Test("Les 26 cantons ont une liste, huit jours cantonaux au plus", arguments: SwissCanton.allCases)
    func everyCanton(canton: SwissCanton) {
        #expect(SwissCanton.allCases.count == 26)
        #expect(!canton.regions.isEmpty)
        for region in canton.regions {
            for year in 2022...2033 {
                let days = region.holidays(in: year)
                #expect(days.count - 1 <= 8, "\(region.rawValue) \(year)")
                #expect(days.contains { $0.holiday == .nationalDay })
                #expect(days.map(\.date) == days.map(\.date).sorted())
                #expect(Set(days.map(\.date)).count == days.count, "\(region.rawValue) \(year)")
            }
        }
    }

    @Test("Seuls AG, FR, NE et SO ont plusieurs régions")
    func regions() {
        let several = SwissCanton.allCases.filter { $0.regions.count > 1 }.map(\.rawValue)
        #expect(several == ["AG", "FR", "NE", "SO"])
    }

    @Test("Pâques", arguments: [
        (2024, "2024-03-31"), (2025, "2025-04-20"), (2026, "2026-04-05"),
        (2027, "2027-03-28"), (2038, "2038-04-25"), (2049, "2049-04-18")
    ])
    func easter(year: Int, expected: String) {
        #expect(text(SwissHolidayCalendar.easterSunday(year)) == expected)
    }

    @Test("Dates mobiles", arguments: [
        (SwissHoliday.goodFriday, 2026, "2026-04-03"), (.easterMonday, 2026, "2026-04-06"),
        (.ascension, 2026, "2026-05-14"), (.whitMonday, 2026, "2026-05-25"),
        (.corpusChristi, 2026, "2026-06-04"),
        (.genevaFast, 2025, "2025-09-11"), (.genevaFast, 2026, "2026-09-10"),
        (.federalFastMonday, 2025, "2025-09-22"), (.federalFastMonday, 2026, "2026-09-21"),
        (.fahrtsfest, 2025, "2025-04-03"), (.fahrtsfest, 2026, "2026-04-09"), (.fahrtsfest, 2027, "2027-04-01")
    ])
    func movable(holiday: SwissHoliday, year: Int, expected: String) {
        #expect(text(SwissHolidayCalendar.date(of: holiday, year: year)) == expected)
    }

    @Test("Saint-Étienne en Appenzell : pas si Noël est un lundi ou un vendredi")
    func appenzell() {
        for region in [SwissHolidayRegion.AI, .AR] {
            #expect(has(region, .saintStephen, 2025)) // jeudi
            #expect(!has(region, .saintStephen, 2026)) // vendredi
            #expect(!has(region, .saintStephen, 2028)) // lundi
        }
    }

    @Test("Neuchâtel : 2 janvier et 26 décembre seulement un lundi")
    func neuchatel() {
        #expect(has(.NE, .berchtold, 2023))
        #expect(!has(.NE, .berchtold, 2026))
        #expect(has(.NE, .saintStephen, 2022))
        #expect(!has(.NE, .saintStephen, 2026))
        #expect(!has(.NE, .corpusChristi, 2026))
        #expect(has(.neLanderon, .corpusChristi, 2026))
    }

    @Test("Soleure : 1er mai l'après-midi, Bucheggberg à part")
    func solothurn() {
        for region in [SwissHolidayRegion.SO, .soBucheggberg] {
            #expect(region.holidays(in: 2026).first { $0.holiday == .labourDay }?.isAfternoonOnly == true)
        }
        #expect(!has(.soBucheggberg, .allSaints, 2026))
        #expect(has(.SO, .allSaints, 2026))
    }

    @Test("Recherche par date")
    func lookup() throws {
        let noon = try #require(SwissHolidayCalendar.gregorian.date(
            from: DateComponents(year: 2026, month: 5, day: 14, hour: 12)))
        #expect(SwissHolidayCalendar.holiday(on: noon, region: .VD)?.holiday == .ascension)
        let next = try #require(SwissHolidayCalendar.gregorian.date(byAdding: .day, value: 1, to: noon))
        #expect(SwissHolidayCalendar.holiday(on: next, region: .VD) == nil)
    }
}

@MainActor
@Suite("Ajout des jours fériés", .serialized)
struct SwissHolidayImporterTests {
    private func makeImporter() throws -> SwissHolidayImporter {
        let schema = Schema([WorkDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let settings = UserSettings(store: nil) // lundi–vendredi
        let today = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        return SwissHolidayImporter(context: ModelContext(container), settings: settings, today: today)
    }

    @Test("Ajoute les jours travaillés libres, une seule fois")
    func addsOnce() throws {
        let importer = try makeImporter()
        let days = SwissHolidayRegion.VD.holidays(in: 2026)
        // 2026 : 1er août (samedi) exclu.
        #expect(days.count == 9)
        #expect(try importer.add(days) == 8)
        #expect(try importer.add(days) == 0)
        let entries = try importer.context.fetch(FetchDescriptor<WorkDay>())
        #expect(entries.count == 8)
        #expect(entries.allSatisfy { $0.type == .holiday && $0.overtimeSeconds == 0 && $0.totalHours == 0 })
        #expect(entries.contains { $0.note == SwissHoliday.ascension.localizedName })
    }

    @Test("Ne touche pas une journée déjà saisie")
    func keepsExisting() throws {
        let importer = try makeImporter()
        let days = SwissHolidayRegion.VD.holidays(in: 2026)
        let ascension = try #require(days.first { $0.holiday == .ascension })
        importer.context.insert(WorkDay(date: ascension.date.addingTimeInterval(9 * 3600), totalHours: 6, type: .work))
        try importer.context.save()
        #expect(try importer.add(days) == 7)
        let same = try importer.entries(for: [ascension])
        #expect(same.values.flatMap { $0 }.map(\.type) == [.work])
    }

    @Test("Ni demi-jour férié, ni au-delà d'un an")
    func limits() throws {
        let importer = try makeImporter()
        let solothurn = SwissHolidayRegion.SO.holidays(in: 2026)
        #expect(try !importer.missing(in: solothurn).contains { $0.holiday == .labourDay })
        let next = try importer.missing(in: SwissHolidayRegion.VD.holidays(in: 2027))
        #expect(next.map(\.holiday) == [.newYear])
    }

    @Test("Deux fériés le même jour : une seule journée")
    func sameDay() throws {
        var importer = try makeImporter()
        importer.today = try #require(Calendar.current.date(from: DateComponents(year: 2008, month: 1, day: 5)))
        // En 2008, l'Ascension tombait le 1er mai.
        let mayFirst = SwissHolidayRegion.NE.holidays(in: 2008).filter { [.labourDay, .ascension].contains($0.holiday) }
        #expect(mayFirst.count == 2)
        #expect(try importer.missing(in: mayFirst).count == 1)
    }
}
