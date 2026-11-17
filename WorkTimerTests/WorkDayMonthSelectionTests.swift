import Foundation
import Testing
@testable import WorkTimer

@Suite("Navigation mensuelle de la liste")
struct WorkDayMonthSelectionTests {
    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    @Test("Le mois visible est toujours normalise au premier jour")
    func visibleMonthIsNormalizedToFirstDay() {
        let calendar = makeCalendar()
        let date = makeDate(year: 2026, month: 5, day: 24, calendar: calendar)
        let selection = WorkDayMonthSelection(date: date, calendar: calendar)

        #expect(selection.year == 2026)
        #expect(selection.month == 5)
        #expect(calendar.component(.day, from: selection.startDate) == 1)
    }

    @Test("La navigation mensuelle garde annee et mois synchronises")
    func monthNavigationKeepsYearAndMonthTogether() throws {
        let calendar = makeCalendar()
        let december = WorkDayMonthSelection(
            date: makeDate(year: 2026, month: 12, day: 31, calendar: calendar),
            calendar: calendar
        )

        let january = try #require(december.addingMonths(1, calendar: calendar))
        let november = try #require(december.addingMonths(-1, calendar: calendar))

        #expect(january.year == 2027)
        #expect(january.month == 1)
        #expect(november.year == 2026)
        #expect(november.month == 11)
    }

    @Test("Le mois visible reconnait uniquement les dates du meme mois")
    func visibleMonthContainsOnlySameMonthDates() {
        let calendar = makeCalendar()
        let selection = WorkDayMonthSelection(
            date: makeDate(year: 2026, month: 2, day: 14, calendar: calendar),
            calendar: calendar
        )

        #expect(selection.contains(makeDate(year: 2026, month: 2, day: 28, calendar: calendar), calendar: calendar))
        #expect(!selection.contains(makeDate(year: 2026, month: 3, day: 1, calendar: calendar), calendar: calendar))
        #expect(!selection.contains(makeDate(year: 2025, month: 2, day: 14, calendar: calendar), calendar: calendar))
    }
}
