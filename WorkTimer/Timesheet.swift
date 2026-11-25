//
//  Timesheet.swift
//  WorkTimer
//
//  Feuille d'heures pour l'employeur : contenu, indépendant du format.
//  Reprend les données de l'art. 73 al. 1 let. c à e OLT 1 que l'app connaît :
//  durées par jour et par semaine, début, fin, durée des pauses, absences.
//  Ni bonus ni rémunération. Les notes sont facultatives.
//

import Foundation

struct Timesheet {
    enum Period: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
    }

    struct Entry {
        let type: WorkDayType
        let start: Date?
        let end: Date?
        let breakMinutes: Int
        let workedMinutes: Int
        let note: String

        var endsNextDay: Bool {
            guard let start, let end else { return false }
            return !Timesheet.calendar.isDate(start, inSameDayAs: end)
        }
    }

    struct Day {
        let date: Date
        let entries: [Entry]
        let balanceMinutes: Int

        var workedMinutes: Int { entries.reduce(0) { $0 + $1.workedMinutes } }
    }

    struct Week {
        let number: Int
        let days: [Day]

        /// La période coupe la semaine : son total ne couvre pas sept jours.
        var isPartial: Bool { days.count < 7 }
        var workedMinutes: Int { days.reduce(0) { $0 + $1.workedMinutes } }
        var balanceMinutes: Int { days.reduce(0) { $0 + $1.balanceMinutes } }
    }

    let period: Period
    let start: Date
    /// Exclu.
    let end: Date
    let weeks: [Week]

    var days: [Day] { weeks.flatMap(\.days) }
    // Sommes de minutes entières : les totaux correspondent aux lignes affichées.
    var workedMinutes: Int { weeks.reduce(0) { $0 + $1.workedMinutes } }
    var balanceMinutes: Int { weeks.reduce(0) { $0 + $1.balanceMinutes } }
    var isEmpty: Bool { days.allSatisfy { $0.entries.isEmpty } }

    /// Jours d'absence par type, dans l'ordre de `WorkDayType`.
    var absences: [(type: WorkDayType, days: Int)] {
        WorkDayType.allCases.filter { !Self.countsAsWork($0) }.compactMap { type in
            let count = days.filter { day in day.entries.contains { $0.type == type } }.count
            return count > 0 ? (type, count) : nil
        }
    }

    /// Semaine du lundi au dimanche, numérotée selon la norme ISO.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func interval(_ period: Period, containing date: Date) -> DateInterval {
        calendar.dateInterval(of: period == .week ? .weekOfYear : .month, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    static func countsAsWork(_ type: WorkDayType) -> Bool {
        type == .work || type == .training
    }

    init(period: Period, containing date: Date, workDays: [WorkDay]) {
        let calendar = Self.calendar
        let interval = Self.interval(period, containing: date)
        let byDay = Dictionary(grouping: workDays.filter {
            !$0.isDeleted && $0.date >= interval.start && $0.date < interval.end
        }) { calendar.startOfDay(for: $0.date) }

        var dates: [Date] = []
        var cursor = interval.start
        while cursor < interval.end, let next = calendar.date(byAdding: .day, value: 1, to: cursor) {
            dates.append(cursor)
            cursor = calendar.startOfDay(for: next)
        }

        let days = dates.map { day -> Day in
            let sorted = (byDay[day] ?? []).sorted {
                ($0.startTime ?? $0.createdAt) < ($1.startTime ?? $1.createdAt)
            }
            let balance = sorted.reduce(0) { $0 + $1.overtimeSeconds }
            return Day(
                date: day,
                entries: sorted.map(Self.entry),
                balanceMinutes: Int((Double(balance) / 60).rounded())
            )
        }

        self.period = period
        start = interval.start
        end = interval.end
        weeks = Dictionary(grouping: days) { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date }
            .sorted { $0.key < $1.key }
            .map { Week(number: calendar.component(.weekOfYear, from: $0.key), days: $0.value) }
    }

    private static func entry(_ workDay: WorkDay) -> Entry {
        let works = countsAsWork(workDay.type)
        return Entry(
            type: workDay.type,
            start: workDay.startTime,
            end: workDay.endTime,
            breakMinutes: workDay.startTime == nil ? 0 : Int((workDay.breakDuration / 60).rounded()),
            workedMinutes: works ? Int((workDay.totalHours * 60).rounded()) : 0,
            note: workDay.note ?? ""
        )
    }

    // MARK: - Texte commun au PDF et au CSV

    struct Options {
        var employee = ""
        var company = ""
        var useDecimalHours = false
        var includeNotes = false
        var locale = Locale.current
    }

    static func duration(_ minutes: Int, decimal: Bool) -> String {
        if decimal {
            return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
        }
        return String(format: "%@%d:%02d", minutes < 0 ? "-" : "", abs(minutes) / 60, abs(minutes) % 60)
    }

    static func balance(_ minutes: Int, decimal: Bool) -> String {
        (minutes > 0 ? "+" : "") + duration(minutes, decimal: decimal)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "" }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Nom de fichier stable : « WorkTimer-2026-S48 » ou « WorkTimer-2026-11 ».
    var fileName: String {
        let calendar = Self.calendar
        switch period {
        case .week:
            let year = calendar.component(.yearForWeekOfYear, from: start)
            return String(format: "WorkTimer-%d-W%02d", year, calendar.component(.weekOfYear, from: start))
        case .month:
            return String(format: "WorkTimer-%d-%02d-timesheet",
                          calendar.component(.year, from: start), calendar.component(.month, from: start))
        }
    }

    func title(locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Self.calendar
        switch period {
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
            return formatter.string(from: start)
        case .week:
            formatter.dateStyle = .medium
            let last = Self.calendar.date(byAdding: .day, value: -1, to: end) ?? start
            let range = "\(formatter.string(from: start)) – \(formatter.string(from: last))"
            return "timesheet.week.title".localized(weeks.first?.number ?? 0, range)
        }
    }
}

// MARK: - CSV

extension Timesheet {
    /// Une ligne par saisie ; un jour sans saisie garde une ligne vide. Les totaux
    /// du jour et de la semaine sont sur leur dernière ligne, pour rester additionnables.
    func csv(options: Options) -> String {
        func text(_ minutes: Int) -> String { Self.duration(minutes, decimal: options.useDecimalHours) }
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Self.calendar
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "dd.MM.yyyy"

        var header = ["name", "week", "date", "type", "start", "end", "break", "worked", "dayTotal", "weekTotal", "balance"]
        if options.includeNotes { header.append("note") }
        var rows = [header.map { "timesheet.column.\($0)".localized }]

        for week in weeks {
            for (dayIndex, day) in week.days.enumerated() {
                let entries: [Entry?] = day.entries.isEmpty ? [nil] : day.entries
                for (index, entry) in entries.enumerated() {
                    let lastOfDay = index == entries.count - 1
                    let lastOfWeek = lastOfDay && dayIndex == week.days.count - 1
                    let works = entry.map { Self.countsAsWork($0.type) } ?? false
                    var row = [
                        options.employee,
                        String(week.number),
                        dateFormatter.string(from: day.date),
                        entry?.type.localizedName ?? "",
                        Self.time(entry?.start),
                        Self.time(entry?.end),
                        works && entry?.start != nil ? text(entry?.breakMinutes ?? 0) : "",
                        works ? text(entry?.workedMinutes ?? 0) : "",
                        lastOfDay && !day.entries.isEmpty ? text(day.workedMinutes) : "",
                        lastOfWeek ? text(week.workedMinutes) : "",
                        lastOfDay && !day.entries.isEmpty
                            ? Self.balance(day.balanceMinutes, decimal: options.useDecimalHours) : ""
                    ]
                    if options.includeNotes { row.append(entry?.note ?? "") }
                    rows.append(row)
                }
            }
        }
        return CSVService.shared.csv(rows)
    }
}
