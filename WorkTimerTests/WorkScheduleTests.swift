import Foundation
import Testing
@testable import WorkTimer

// MARK: - Helpers

private func makeScheduleCalendar(firstWeekday: Int = 2) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = firstWeekday
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}

private func makeScheduleDate(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.timeZone = calendar.timeZone
    return calendar.date(from: components)!
}

// MARK: - Logique pure des horaires
//
// Ces tests ne touchent à aucun état global (pas de UserSettings.shared) :
// ils ciblent uniquement les fonctions statiques pures, donc restent
// parallélisables et déterministes.

@Suite("Horaires de travail — logique pure")
struct WorkScheduleLogicTests {

    // normalizedWeek

    @Test("normalizedWeek conserve un tableau de 7 valeurs déjà valides")
    func normalizedWeekKeepsValidWeek() {
        let week: [Double] = [9, 9, 9, 9, 5, 0, 0]
        #expect(UserSettings.normalizedWeek(week) == week)
    }

    @Test("normalizedWeek complète un tableau trop court avec des zéros")
    func normalizedWeekPadsShortArray() {
        #expect(UserSettings.normalizedWeek([8, 8]) == [8, 8, 0, 0, 0, 0, 0])
    }

    @Test("normalizedWeek tronque un tableau trop long à 7 valeurs")
    func normalizedWeekTruncatesLongArray() {
        let result = UserSettings.normalizedWeek([1, 2, 3, 4, 5, 6, 7, 8, 9])
        #expect(result == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test("normalizedWeek borne chaque valeur entre 0 et 24 heures")
    func normalizedWeekClampsValues() {
        let result = UserSettings.normalizedWeek([-5, 30, 8, 0, 24, 24.5, -0.1])
        #expect(result == [0, 24, 8, 0, 24, 24, 0])
    }

    @Test("normalizedWeek remplace les valeurs non finies par 0")
    func normalizedWeekHandlesNonFinite() {
        let result = UserSettings.normalizedWeek([.nan, .infinity, 8, 0, 0, 0, 0])
        #expect(result == [0, 0, 8, 0, 0, 0, 0])
    }

    // weekdayIndex (Lun = 0 … Dim = 6)

    @Test("weekdayIndex mappe lundi→0 … dimanche→6")
    func weekdayIndexMapsMondayFirst() {
        let calendar = makeScheduleCalendar()

        // Trouver un lundi déterministe.
        var monday = makeScheduleDate(2026, 6, 1, calendar)
        while calendar.component(.weekday, from: monday) != 2 {
            monday = calendar.date(byAdding: .day, value: 1, to: monday)!
        }

        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            #expect(UserSettings.weekdayIndex(for: date, calendar: calendar) == offset)
        }

        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        #expect(calendar.component(.weekday, from: sunday) == 1)
        #expect(UserSettings.weekdayIndex(for: sunday, calendar: calendar) == 6)
    }

    // expectedHours — mode par jour

    @Test("Mode par jour : chaque jour renvoie sa cible (ex. vendredi = 5h)")
    func expectedHoursPerDay() {
        let daily: [Double] = [9, 9, 9, 9, 5, 0, 0]
        let working = [Bool](repeating: true, count: 7)

        // Lundi (index 0)
        #expect(UserSettings.expectedHours(weekdayIndex: 0, useCustom: true, dailyHours: daily, workingDays: working, standardDailyHours: 99) == 9)
        // Vendredi (index 4)
        #expect(UserSettings.expectedHours(weekdayIndex: 4, useCustom: true, dailyHours: daily, workingDays: working, standardDailyHours: 99) == 5)
        // Samedi (index 5) = repos
        #expect(UserSettings.expectedHours(weekdayIndex: 5, useCustom: true, dailyHours: daily, workingDays: working, standardDailyHours: 99) == 0)
    }

    @Test("Mode par jour : un tableau incomplet renvoie 0 pour les jours manquants")
    func expectedHoursPerDayShortArray() {
        let result = UserSettings.expectedHours(weekdayIndex: 4, useCustom: true, dailyHours: [9, 9], workingDays: [], standardDailyHours: 8)
        #expect(result == 0)
    }

    // expectedHours — mode uniforme

    @Test("Mode uniforme : jour travaillé → heures standard, sinon 0")
    func expectedHoursUniform() {
        let working = [true, true, true, true, true, false, false]

        // Lundi travaillé
        #expect(abs(UserSettings.expectedHours(weekdayIndex: 0, useCustom: false, dailyHours: [], workingDays: working, standardDailyHours: 8.2) - 8.2) < 1e-9)
        // Samedi non travaillé
        #expect(UserSettings.expectedHours(weekdayIndex: 5, useCustom: false, dailyHours: [], workingDays: working, standardDailyHours: 8.2) == 0)
    }

    // Bornes

    @Test("Un index hors plage renvoie 0 dans les deux modes")
    func expectedHoursOutOfRange() {
        let daily: [Double] = [9, 9, 9, 9, 5, 0, 0]
        let working = [Bool](repeating: true, count: 7)
        #expect(UserSettings.expectedHours(weekdayIndex: 7, useCustom: true, dailyHours: daily, workingDays: working, standardDailyHours: 8) == 0)
        #expect(UserSettings.expectedHours(weekdayIndex: -1, useCustom: false, dailyHours: daily, workingDays: working, standardDailyHours: 8) == 0)
    }
}
