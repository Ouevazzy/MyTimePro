//
//  CalendarSections.swift
//  WorkTimer
//
//  Vues annuelle et mensuelle (scroll continu) du calendrier.
//

import SwiftUI

// MARK: - Vue annuelle

struct YearSectionView: View {
    let year: Int
    let selectedDate: Date
    let today: Date
    let calendar: Calendar
    let onSelectMonth: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var isCurrentYear: Bool {
        calendar.component(.year, from: today) == year
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(year))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrentYear ? Color.red : Color.primary)
                .contentTransition(.numericText())

            LazyVGrid(columns: columns, alignment: .leading, spacing: DS.Spacing.lg) {
                ForEach(1...12, id: \.self) { month in
                    if let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                        Button {
                            onSelectMonth(date)
                        } label: {
                            MiniMonthView(
                                month: date,
                                selectedDate: selectedDate,
                                today: today,
                                calendar: calendar
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(.dateTime.month(.wide).year()))
                        .accessibilityHint("calendar.year.monthHint".localized)
                        .accessibilityIdentifier(
                            String(format: "calendar-month-%04d-%02d", year, month)
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("calendar-year-\(year)")
    }
}

struct MiniMonthView: View {
    let month: Date
    let selectedDate: Date
    let today: Date
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.wide)))
                .font(.headline)
                .foregroundStyle(isCurrentMonth ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(CalendarGridLayout.monthSlots(for: month, calendar: calendar)) { slot in
                    if let date = slot.date {
                        ZStack {
                            if calendar.isDate(date, inSameDayAs: today) {
                                Circle().fill(Color.red)
                            } else if calendar.isDate(date, inSameDayAs: selectedDate) {
                                Circle().stroke(Color.primary, lineWidth: 1)
                            }

                            Text(String(calendar.component(.day, from: date)))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    calendar.isDate(date, inSameDayAs: today)
                                        ? Color.white
                                        : calendar.isDateInWeekend(date) ? .secondary : .primary
                                )
                        }
                        .frame(height: 13)
                    } else {
                        Color.clear.frame(height: 13)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: today, toGranularity: .month)
    }
}

// MARK: - Section de mois (scroll continu)

/// Un mois du scroll continu : titre inline + grille de semaines séparées par un filet.
/// ✅ Equatable : pendant le scroll (displayDate change) ou une sélection dans un
/// autre mois, `==` reste vrai et SwiftUI saute entièrement le re-rendu de la
/// section (~35 cellules avec contextMenu chacune). C'est ce qui rend le scroll
/// continu fluide, façon Calendrier Apple.
struct MonthSectionView: View, Equatable {
    let month: Date
    let slots: [CalendarMonthSlot]
    /// Date sélectionnée si elle tombe dans ce mois, sinon nil.
    let selectedDate: Date?
    /// startOfDay du jour courant — passé en paramètre pour rester dans `==`.
    let today: Date
    let showWeekNumbers: Bool
    let eventDisplayMode: CalendarEventDisplayMode
    /// Incrémenté à chaque nouveau fetch : force le re-rendu quand les données changent.
    let workDaysVersion: Int
    let holidayRegion: SwissHolidayRegion?
    let calendar: Calendar
    let findWorkDays: (Date) -> [WorkDay]
    let onSelect: (Date, WorkDay?) -> Void
    let onEdit: (WorkDay) -> Void
    let onDelete: (WorkDay) -> Void
    let onAdd: (Date) -> Void

    // `slots` dérive de `month` (cache), `calendar` est constant, les closures
    // lisent l'état à jour via les boxes @State : seuls ces champs comptent.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.month == rhs.month &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.today == rhs.today &&
        lhs.showWeekNumbers == rhs.showWeekNumbers &&
        lhs.eventDisplayMode == rhs.eventDisplayMode &&
        lhs.workDaysVersion == rhs.workDaysVersion &&
        lhs.holidayRegion == rhs.holidayRegion
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: today, toGranularity: .month)
    }

    /// Jours fériés du mois, calculés une fois par rendu de section.
    private var monthHolidays: [SwissHolidayDay] {
        guard let holidayRegion else { return [] }
        let year = SwissHolidayCalendar.gregorian.component(.year, from: month)
        return holidayRegion.holidays(in: year).filter {
            calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
    }

    var body: some View {
        let holidays = monthHolidays
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Le mois courant est teinté, façon Calendrier Apple.
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(isCurrentMonth ? Color.blue : Color.primary)
                .padding(.leading, DS.Spacing.xs)
                .padding(.top, DS.Spacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(stride(from: 0, to: slots.count, by: 7)), id: \.self) { weekStart in
                    if weekStart > 0 {
                        Divider()
                    }

                    HStack(alignment: .top, spacing: 0) {
                        if showWeekNumbers {
                            Text(weekNumberText(for: slots[weekStart..<min(weekStart + 7, slots.count)]))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.tertiary)
                                .frame(width: 22, alignment: .leading)
                                .padding(.top, DS.Spacing.md)
                        }

                        ForEach(slots[weekStart..<min(weekStart + 7, slots.count)]) { slot in
                            if let date = slot.date {
                                dayCell(for: date, holiday: holidays.first { calendar.isDate($0.date, inSameDayAs: date) })
                            } else {
                                // Cellule vide
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func dayCell(for date: Date, holiday: SwissHolidayDay?) -> some View {
        let workDays = findWorkDays(date)
        let workDay = workDays.first
        let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return Button {
            onSelect(date, workDay)
        } label: {
            ImprovedCalendarCell(
                date: date,
                workDays: workDays,
                isSelected: isSelected,
                isToday: isToday,
                isWeekend: calendar.isDateInWeekend(date),
                eventDisplayMode: eventDisplayMode,
                isHoliday: holiday != nil
            )
        }
        .buttonStyle(.plain)
        // Appui long : actions rapides sans passer par la carte de détail
        .contextMenu {
            if let workDay {
                Button {
                    onEdit(workDay)
                } label: {
                    Label("action.edit".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete(workDay)
                } label: {
                    Label("action.delete".localized, systemImage: "trash")
                }
            } else {
                Button {
                    onAdd(date)
                } label: {
                    Label("action.add".localized, systemImage: "plus")
                }
            }
        }
        .accessibilityIdentifier("calendar-day-\(CalendarGridLayout.dateIdentity(for: date, calendar: calendar))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: date, workDays: workDays, isToday: isToday, holiday: holiday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            onSelect(date, workDay)
        }
    }

    /// « Juin », ou « Juin 2027 » si l'année diffère de l'année en cours.
    private var title: String {
        let name = month.formatted(.dateTime.month(.wide)).capitalized
        let year = calendar.component(.year, from: month)
        let currentYear = calendar.component(.year, from: today)
        return year == currentYear ? name : "\(name) \(year)"
    }

    private func weekNumberText(for slots: ArraySlice<CalendarMonthSlot>) -> String {
        guard let date = slots.compactMap(\.date).first else { return "" }
        return String(calendar.component(.weekOfYear, from: date))
    }

    private func accessibilityLabel(for date: Date, workDays: [WorkDay], isToday: Bool, holiday: SwissHolidayDay?) -> String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())]

        if isToday {
            parts.append("calendar.today".localized)
        }

        if let holiday {
            parts.append(holiday.title)
        }

        if !workDays.isEmpty {
            if workDays.count > 1 {
                parts.append("workDays.entries.count".localized(workDays.count))
            }
            let types = WorkDayType.allCases.filter { type in workDays.contains { $0.type == type } }
            parts.append(contentsOf: types.map(\.localizedName))
            let hours = workDays.reduce(0) { $0 + $1.totalHours }
            parts.append("calendar.preview.hours".localized(WorkTimeCalculations.formattedHoursRounded(hours)))
        }

        return parts.joined(separator: ", ")
    }
}
