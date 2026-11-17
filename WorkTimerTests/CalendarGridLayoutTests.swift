import Foundation
import Testing
@testable import WorkTimer

@Suite("Disposition du calendrier")
struct CalendarGridLayoutTests {
    private func makeCalendar(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    @Test("Le calendrier d'affichage commence le lundi")
    func displayCalendarStartsOnMonday() {
        #expect(CalendarGridLayout.displayCalendar.firstWeekday == 2)
    }

    @Test("L'en-tete des jours suit le meme ordre que la grille")
    func weekdaySymbolsFollowGridOrder() {
        let calendar = makeCalendar(firstWeekday: 2)
        let symbols = CalendarGridLayout.weekdaySymbols(for: calendar)

        #expect(symbols.count == 7)
        #expect(symbols.first == calendar.shortWeekdaySymbols[1].lowercased())
        #expect(symbols.last == calendar.shortWeekdaySymbols[0].lowercased())
    }

    @Test("La grille mensuelle aligne un dimanche en derniere colonne quand la semaine commence lundi")
    func monthGridAlignsSundayAtEndForMondayFirstCalendar() throws {
        let calendar = makeCalendar(firstWeekday: 2)
        let septemberFirst = makeDate(year: 2024, month: 9, day: 1, calendar: calendar)
        let dates = CalendarGridLayout.monthDates(for: septemberFirst, calendar: calendar)

        #expect(dates.prefix(6).allSatisfy { $0 == nil })

        let firstVisibleDate = try #require(dates[6])
        #expect(calendar.component(.day, from: firstVisibleDate) == 1)
        #expect(calendar.component(.weekday, from: firstVisibleDate) == 1)
    }

    @Test("La date d'affichage mensuelle est toujours le debut du mois")
    func monthDisplayDateUsesStartOfMonth() {
        let calendar = makeCalendar(firstWeekday: 2)
        let date = makeDate(year: 2026, month: 6, day: 30, calendar: calendar)
        let displayDate = CalendarGridLayout.monthDisplayDate(for: date, calendar: calendar)

        #expect(calendar.component(.year, from: displayDate) == 2026)
        #expect(calendar.component(.month, from: displayDate) == 6)
        #expect(calendar.component(.day, from: displayDate) == 1)
    }

    @Test("Les cases du mois utilisent une identite basee sur la date visible")
    func monthSlotsUseDateIdentityForVisibleDays() throws {
        let calendar = makeCalendar(firstWeekday: 2)
        let june = makeDate(year: 2026, month: 6, day: 1, calendar: calendar)
        let slots = CalendarGridLayout.monthSlots(for: june, calendar: calendar)

        let firstDay = try #require(slots.first { $0.date.map { calendar.component(.day, from: $0) == 1 } ?? false })
        let thirtieth = try #require(slots.first { $0.date.map { calendar.component(.day, from: $0) == 30 } ?? false })

        #expect(firstDay.id == "day-2026-06-01")
        #expect(thirtieth.id == "day-2026-06-30")
        #expect(Set(slots.map(\.id)).count == slots.count)
    }

    @Test("La navigation mensuelle conserve le jour prefere apres un mois plus court")
    func monthNavigationPreservesPreferredDayAfterShortMonth() throws {
        let calendar = makeCalendar(firstWeekday: 2)
        let january = makeDate(year: 2026, month: 1, day: 31, calendar: calendar)

        let february = try #require(CalendarGridLayout.monthNavigation(
            from: january,
            preferredDay: 31,
            by: 1,
            calendar: calendar
        ))
        let march = try #require(CalendarGridLayout.monthNavigation(
            from: february.displayDate,
            preferredDay: 31,
            by: 1,
            calendar: calendar
        ))

        #expect(calendar.component(.month, from: february.displayDate) == 2)
        #expect(calendar.component(.day, from: february.displayDate) == 1)
        #expect(calendar.component(.day, from: february.selectedDate) == 28)
        #expect(calendar.component(.month, from: march.displayDate) == 3)
        #expect(calendar.component(.day, from: march.selectedDate) == 31)
    }

    @Test("La vue semaine commence sur le lundi visible")
    func weekDatesStartOnVisibleMonday() throws {
        let calendar = makeCalendar(firstWeekday: 2)
        let wednesday = makeDate(year: 2024, month: 9, day: 4, calendar: calendar)
        let weekDates = CalendarGridLayout.weekDates(for: wednesday, calendar: calendar)

        #expect(weekDates.count == 7)

        let firstDay = try #require(weekDates.first)
        let lastDay = try #require(weekDates.last)

        #expect(calendar.component(.weekday, from: firstDay) == 2)
        #expect(calendar.component(.day, from: firstDay) == 2)
        #expect(calendar.component(.day, from: lastDay) == 8)
    }
}
