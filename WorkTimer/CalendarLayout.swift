//
//  CalendarLayout.swift
//  WorkTimer
//
//  Modes d'affichage et calculs de grille du calendrier.
//

import Foundation

enum CalendarViewMode: Hashable {
    case year
    case month
    case week
}

enum CalendarEventDisplayMode: String, CaseIterable, Hashable {
    case compact
    case stack
    case details

    var title: String {
        switch self {
        case .compact: return "calendar.view.compact".localized
        case .stack: return "calendar.view.stack".localized
        case .details: return "calendar.view.details".localized
        }
    }
}

struct CalendarMonthSlot: Identifiable, Hashable {
    let id: String
    let date: Date?
}

/// Calculs purs de grille, dérivés directement du mois ou de la semaine affichée.
enum CalendarGridLayout {
    static var displayCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func dateIdentity(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func monthDisplayDate(for date: Date, calendar: Calendar) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return calendar.startOfDay(for: date)
        }
        return calendar.startOfDay(for: interval.start)
    }

    static func weekdaySymbols(for calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        guard !symbols.isEmpty else { return [] }

        let firstIndex = min(max(calendar.firstWeekday - 1, 0), symbols.count - 1)
        return (Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex]))
            .map { $0.lowercased() }
    }

    static func monthDates(for date: Date, calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }

        let firstDayOfMonth = calendar.startOfDay(for: interval.start)
        guard let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count else {
            return []
        }

        let startDayIndex = (calendar.component(.weekday, from: firstDayOfMonth) - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = []
        for _ in 0..<startDayIndex {
            dates.append(nil)
        }
        for dayOffset in 0..<numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                dates.append(calendar.startOfDay(for: date))
            }
        }
        while dates.count % 7 != 0 {
            dates.append(nil)
        }
        return dates
    }

    static func monthSlots(for date: Date, calendar: Calendar) -> [CalendarMonthSlot] {
        let monthID = dateIdentity(for: monthDisplayDate(for: date, calendar: calendar), calendar: calendar)

        return monthDates(for: date, calendar: calendar).enumerated().map { index, date in
            if let date {
                return CalendarMonthSlot(
                    id: "day-\(dateIdentity(for: date, calendar: calendar))",
                    date: date
                )
            }

            return CalendarMonthSlot(id: "empty-\(monthID)-\(index)", date: nil)
        }
    }

    // ✅ Memoïsation des grilles de mois : les slots d'un mois sont immuables,
    // inutile de refaire les calculs Calendar (~35 cellules) à chaque render.
    @MainActor private static var slotsCache: [Date: [CalendarMonthSlot]] = [:]

    @MainActor
    static func cachedMonthSlots(for date: Date, calendar: Calendar) -> [CalendarMonthSlot] {
        let month = monthDisplayDate(for: date, calendar: calendar)
        if let cached = slotsCache[month] {
            return cached
        }
        let slots = monthSlots(for: month, calendar: calendar)
        slotsCache[month] = slots
        return slots
    }

    static func monthNavigation(
        from displayDate: Date,
        preferredDay: Int,
        by offset: Int,
        calendar: Calendar
    ) -> (displayDate: Date, selectedDate: Date)? {
        let sourceMonth = monthDisplayDate(for: displayDate, calendar: calendar)
        guard let shiftedMonth = calendar.date(byAdding: .month, value: offset, to: sourceMonth) else {
            return nil
        }

        let targetMonth = monthDisplayDate(for: shiftedMonth, calendar: calendar)
        let numberOfDays = calendar.range(of: .day, in: .month, for: targetMonth)?.count ?? preferredDay
        let selectedDay = min(max(preferredDay, 1), numberOfDays)
        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        components.day = selectedDay

        guard let selectedDate = calendar.date(from: components) else {
            return nil
        }

        return (
            displayDate: targetMonth,
            selectedDate: calendar.startOfDay(for: selectedDate)
        )
    }

    static func weekDates(for date: Date, calendar: Calendar) -> [Date] {
        let normalizedDate = calendar.startOfDay(for: date)
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: normalizedDate)) else {
            return []
        }
        return (0...6).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day, to: weekStart) else {
                return nil
            }
            return calendar.startOfDay(for: date)
        }
    }
}
