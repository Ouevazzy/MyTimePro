//
//  SwissHolidays.swift
//  WorkTimer
//
//  Jours fériés suisses assimilés au dimanche, par canton.
//  Source : SECO, annexe « Jours fériés en Suisse », état au 12.12.2024
//  (tableau et exceptions AG, AI, AR, FR, NE, SO). Calcul hors ligne.
//

import Foundation

enum SwissHoliday: String, CaseIterable {
    case newYear, berchtold, epiphany, neuchatelRepublic, saintJoseph, fahrtsfest
    case goodFriday, easterMonday, labourDay, ascension, whitMonday, corpusChristi
    case nationalDay, assumption, genevaFast, federalFastMonday
    case allSaints, immaculateConception, christmas, saintStephen, genevaRestoration

    var localizedName: String { "swissHoliday.\(rawValue)".localized }
}

enum SwissCanton: String, CaseIterable, Identifiable {
    case AG, AI, AR, BE, BL, BS, FR, GE, GL, GR, JU, LU, NE, NW, OW
    case SG, SH, SO, SZ, TG, TI, UR, VD, VS, ZG, ZH

    var id: String { rawValue }
    var localizedName: String { "swissCanton.\(rawValue)".localized }
    var regions: [SwissHolidayRegion] { SwissHolidayRegion.allCases.filter { $0.canton == self } }
}

/// Territoire ayant sa propre liste. Un canton a une seule région, sauf AG, FR,
/// NE et SO où la liste change selon le district ou la commune.
/// `rawValue` est enregistré dans les réglages : ne pas le renommer.
enum SwissHolidayRegion: String, CaseIterable, Identifiable {
    case agAarau = "AG-aarau", agBaden = "AG-baden", agBremgarten = "AG-bremgarten"
    case agMuri = "AG-muri", agFricktal = "AG-fricktal", agRheinfelden = "AG-rheinfelden"
    case agZurzach = "AG-zurzach"
    case AI, AR, BE, BL, BS
    case frCatholic = "FR-catholic", frReformed = "FR-reformed"
    case GE, GL, GR, JU, LU
    case NE, neLanderon = "NE-landeron"
    case NW, OW, SG, SH
    case SO, soBucheggberg = "SO-bucheggberg"
    case SZ, TG, TI, UR, VD, VS, ZG, ZH

    var id: String { rawValue }
    var canton: SwissCanton { SwissCanton(rawValue: String(rawValue.prefix(2)))! }
    /// Libellé du territoire, utile seulement dans les cantons à plusieurs régions.
    var localizedName: String {
        canton.regions.count > 1 ? "swissRegion.\(rawValue)".localized : canton.localizedName
    }

    /// Jours assimilés au dimanche, sans le 1er août qui vaut partout.
    private var cantonal: Set<SwissHoliday> {
        switch self {
        case .agAarau:
            [.newYear, .berchtold, .goodFriday, .easterMonday, .ascension, .whitMonday, .christmas, .saintStephen]
        case .agBaden:
            [.newYear, .goodFriday, .easterMonday, .ascension, .whitMonday, .corpusChristi, .christmas, .saintStephen]
        case .agBremgarten:
            [.newYear, .goodFriday, .ascension, .corpusChristi, .assumption, .allSaints, .christmas, .saintStephen]
        case .agMuri, .agFricktal:
            [.newYear, .goodFriday, .ascension, .corpusChristi, .assumption, .allSaints, .immaculateConception, .christmas]
        case .agRheinfelden:
            [.newYear, .goodFriday, .easterMonday, .ascension, .whitMonday, .allSaints, .christmas, .saintStephen]
        case .agZurzach:
            [.newYear, .berchtold, .goodFriday, .ascension, .corpusChristi, .allSaints, .christmas, .saintStephen]
        case .AI:
            [.newYear, .goodFriday, .easterMonday, .ascension, .whitMonday, .corpusChristi, .christmas, .saintStephen]
        case .AR, .GR:
            [.newYear, .goodFriday, .easterMonday, .ascension, .whitMonday, .christmas, .saintStephen]
        case .BE, .TG, .frReformed:
            [.newYear, .berchtold, .goodFriday, .easterMonday, .ascension, .whitMonday, .christmas, .saintStephen]
        case .BL, .BS, .SH, .ZH:
            [.newYear, .goodFriday, .easterMonday, .labourDay, .ascension, .whitMonday, .christmas, .saintStephen]
        case .frCatholic, .NW, .OW, .UR, .ZG:
            [.newYear, .goodFriday, .ascension, .corpusChristi, .assumption, .allSaints, .immaculateConception, .christmas]
        case .GE:
            [.newYear, .goodFriday, .easterMonday, .ascension, .whitMonday, .genevaFast, .christmas, .genevaRestoration]
        case .GL:
            [.newYear, .fahrtsfest, .goodFriday, .easterMonday, .ascension, .allSaints, .christmas, .saintStephen]
        case .JU:
            [.newYear, .goodFriday, .easterMonday, .labourDay, .ascension, .whitMonday, .corpusChristi, .christmas]
        case .LU:
            [.newYear, .goodFriday, .ascension, .corpusChristi, .assumption, .allSaints, .christmas, .saintStephen]
        case .NE:
            [.newYear, .berchtold, .neuchatelRepublic, .goodFriday, .labourDay, .ascension, .christmas, .saintStephen]
        case .neLanderon:
            [.newYear, .berchtold, .neuchatelRepublic, .goodFriday, .labourDay, .ascension, .corpusChristi, .christmas, .saintStephen]
        case .SG:
            [.newYear, .goodFriday, .easterMonday, .ascension, .whitMonday, .allSaints, .christmas, .saintStephen]
        case .SO:
            [.newYear, .goodFriday, .labourDay, .ascension, .corpusChristi, .assumption, .allSaints, .christmas]
        case .soBucheggberg:
            [.newYear, .goodFriday, .labourDay, .ascension, .christmas]
        case .SZ:
            [.newYear, .saintJoseph, .goodFriday, .ascension, .corpusChristi, .assumption, .allSaints, .christmas]
        case .TI:
            [.newYear, .epiphany, .easterMonday, .ascension, .assumption, .allSaints, .christmas, .saintStephen]
        case .VD:
            [.newYear, .berchtold, .goodFriday, .easterMonday, .ascension, .whitMonday, .federalFastMonday, .christmas]
        case .VS:
            [.newYear, .saintJoseph, .ascension, .corpusChristi, .assumption, .allSaints, .immaculateConception, .christmas]
        }
    }

    func holidays(in year: Int) -> [SwissHolidayDay] {
        cantonal.union([.nationalDay])
            .compactMap { holiday in
                guard let date = SwissHolidayCalendar.date(of: holiday, year: year),
                      isObserved(holiday, on: date, year: year) else { return nil }
                // Soleure : le 1er mai n'est férié que l'après-midi.
                let afternoonOnly = canton == .SO && holiday == .labourDay
                return SwissHolidayDay(holiday: holiday, date: date, isAfternoonOnly: afternoonOnly)
            }
            .sorted { $0.date < $1.date }
    }

    private func isObserved(_ holiday: SwissHoliday, on date: Date, year: Int) -> Bool {
        let calendar = SwissHolidayCalendar.gregorian
        switch (canton, holiday) {
        case (.AI, .saintStephen), (.AR, .saintStephen):
            // Pas férié si Noël tombe un lundi ou un vendredi. AI le formule
            // autrement (« pas trois jours de repos de suite »), même résultat.
            guard let christmas = SwissHolidayCalendar.date(of: .christmas, year: year) else { return false }
            return ![2, 6].contains(calendar.component(.weekday, from: christmas))
        case (.NE, .berchtold), (.NE, .saintStephen):
            return calendar.component(.weekday, from: date) == 2
        default:
            return true
        }
    }
}

struct SwissHolidayDay: Identifiable, Hashable {
    let holiday: SwissHoliday
    /// Début du jour, heure locale.
    let date: Date
    let isAfternoonOnly: Bool

    var id: SwissHoliday { holiday }
    var title: String {
        isAfternoonOnly
            ? "swissHolidays.afternoonOnly".localized(holiday.localizedName)
            : holiday.localizedName
    }
}

enum SwissHolidayCalendar {
    /// Grégorien quel que soit le calendrier du téléphone, dans le fuseau local.
    static var gregorian: Calendar { Calendar(identifier: .gregorian) }

    static func holiday(on date: Date, region: SwissHolidayRegion) -> SwissHolidayDay? {
        let calendar = gregorian
        return region.holidays(in: calendar.component(.year, from: date))
            .first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    static func date(of holiday: SwissHoliday, year: Int) -> Date? {
        switch holiday {
        case .newYear: day(year, 1, 1)
        case .berchtold: day(year, 1, 2)
        case .epiphany: day(year, 1, 6)
        case .neuchatelRepublic: day(year, 3, 1)
        case .saintJoseph: day(year, 3, 19)
        case .fahrtsfest: fahrtsfest(year)
        case .goodFriday: easter(year, offset: -2)
        case .easterMonday: easter(year, offset: 1)
        case .labourDay: day(year, 5, 1)
        case .ascension: easter(year, offset: 39)
        case .whitMonday: easter(year, offset: 50)
        case .corpusChristi: easter(year, offset: 60)
        case .nationalDay: day(year, 8, 1)
        case .assumption: day(year, 8, 15)
        // Jeudi qui suit le premier dimanche de septembre.
        case .genevaFast: shifted(weekday(1, ordinal: 1, month: 9, year: year), by: 4)
        // Lundi qui suit le troisième dimanche de septembre.
        case .federalFastMonday: shifted(weekday(1, ordinal: 3, month: 9, year: year), by: 1)
        case .allSaints: day(year, 11, 1)
        case .immaculateConception: day(year, 12, 8)
        case .christmas: day(year, 12, 25)
        case .saintStephen: day(year, 12, 26)
        case .genevaRestoration: day(year, 12, 31)
        }
    }

    /// Dimanche de Pâques grégorien (algorithme de Meeus).
    static func easterSunday(_ year: Int) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let n = h + l - 7 * m + 114
        return day(year, n / 31, n % 31 + 1)
    }

    private static func easter(_ year: Int, offset: Int) -> Date? {
        shifted(easterSunday(year), by: offset)
    }

    /// Premier jeudi d'avril, repoussé d'une semaine s'il tombe le Jeudi saint.
    private static func fahrtsfest(_ year: Int) -> Date? {
        guard let thursday = weekday(5, ordinal: 1, month: 4, year: year),
              let maundyThursday = easter(year, offset: -3) else { return nil }
        return thursday == maundyThursday ? shifted(thursday, by: 7) : thursday
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        gregorian.date(from: DateComponents(year: year, month: month, day: day))
            .map { gregorian.startOfDay(for: $0) }
    }

    private static func weekday(_ weekday: Int, ordinal: Int, month: Int, year: Int) -> Date? {
        gregorian.date(from: DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: ordinal))
            .map { gregorian.startOfDay(for: $0) }
    }

    private static func shifted(_ date: Date?, by days: Int) -> Date? {
        date.flatMap { gregorian.date(byAdding: .day, value: days, to: $0) }
    }
}
