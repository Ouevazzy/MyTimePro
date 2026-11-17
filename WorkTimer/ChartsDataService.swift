//
//  ChartsDataService.swift
//  WorkTimer
//
//  Logique de calcul pure pour les graphiques, extraite de ChartsView.
//  Fonctions sans état, testables indépendamment de l'UI.
//

import Foundation

// MARK: - Data Models for Charts

struct WeeklyHoursData: Identifiable {
    /// Clé unique `yearForWeekOfYear * 100 + weekOfYear` : évite les collisions
    /// quand la semaine 1 apparaît deux fois (fin décembre + janvier).
    let id: Int
    let weekNumber: Int
    let weekLabel: String
    let totalHours: Double
    let overtime: Double
    let standardHours: Double
}

struct MonthlyHoursData: Identifiable {
    var id: Int { month }
    let month: Int
    let monthName: String
    let totalHours: Double
    let overtime: Double
    let workDays: Int
}

struct DailyHoursData: Identifiable {
    var id: Date { date }
    let date: Date
    let dayName: String
    let hours: Double
    let type: WorkDayType
}

struct WorkTypeDistribution: Identifiable {
    var id: String { type.rawValue }
    let type: WorkDayType
    let count: Int
    let percentage: Double
}

struct ChartSummary {
    let totalHours: Double
    let overtimeSeconds: Int
    let workDaysCount: Int
    let averageHours: Double

    static let empty = ChartSummary(totalHours: 0, overtimeSeconds: 0, workDaysCount: 0, averageHours: 0)
}

// MARK: - Charts Data Service

/// Transforme une liste de `WorkDay` en jeux de données prêts pour les graphiques.
/// Toutes les méthodes sont pures (entrée -> sortie), sans accès au `ModelContext`.
enum ChartsDataService {

    /// Agrège les heures par semaine de l'année (12 dernières semaines présentes).
    static func weeklyData(from workDays: [WorkDay]) -> [WeeklyHoursData] {
        let calendar = Calendar.current
        let standardWeeklyHours = UserSettings.shared.weeklyHours
        let yearWorkDays = workDays.filter { $0.type == .work }

        // Clé composite année+semaine : les 29–31 décembre (weekOfYear == 1 de
        // l'année suivante) ne fusionnent plus avec la semaine 1 de janvier.
        var weeklyDict: [Int: (hours: Double, overtime: Int)] = [:]

        for day in yearWorkDays {
            let week = calendar.component(.weekOfYear, from: day.date)
            let weekYear = calendar.component(.yearForWeekOfYear, from: day.date)
            let key = weekYear * 100 + week
            let current = weeklyDict[key] ?? (0, 0)
            weeklyDict[key] = (current.hours + day.totalHours, current.overtime + day.overtimeSeconds)
        }

        return weeklyDict.keys.sorted().suffix(12).map { key in
            let data = weeklyDict[key]!
            let week = key % 100
            return WeeklyHoursData(
                id: key,
                weekNumber: week,
                weekLabel: "S\(week)",
                totalHours: data.hours,
                overtime: Double(data.overtime) / 3600.0,
                standardHours: standardWeeklyHours
            )
        }
    }

    /// Agrège les heures par mois pour les mois contenant au moins un jour travaillé.
    static func monthlyData(from workDays: [WorkDay]) -> [MonthlyHoursData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "MMM"
        let yearWorkDays = workDays.filter { $0.type == .work }

        var monthlyDict: [Int: (hours: Double, overtime: Int, dates: Set<Date>)] = [:]

        for day in yearWorkDays {
            let month = calendar.component(.month, from: day.date)
            let current = monthlyDict[month] ?? (0, 0, [])
            var dates = current.dates
            dates.insert(calendar.startOfDay(for: day.date))
            monthlyDict[month] = (current.hours + day.totalHours, current.overtime + day.overtimeSeconds, dates)
        }

        return (1...12).compactMap { month -> MonthlyHoursData? in
            guard let data = monthlyDict[month], !data.dates.isEmpty else {
                return nil
            }
            var components = DateComponents()
            components.month = month
            let date = calendar.date(from: components) ?? Date()

            return MonthlyHoursData(
                month: month,
                monthName: formatter.string(from: date).capitalized,
                totalHours: data.hours,
                overtime: Double(data.overtime) / 3600.0,
                workDays: data.dates.count
            )
        }
    }

    /// Liste les jours ayant des heures > 0, triés par date.
    static func dailyData(from workDays: [WorkDay]) -> [DailyHoursData] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "E"

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workDays.filter { $0.totalHours > 0 }) {
            calendar.startOfDay(for: $0.date)
        }

        return grouped
            .map { date, entries in
                let primary = entries.first(where: { $0.type == .work }) ?? entries[0]
                return DailyHoursData(
                    date: date,
                    dayName: formatter.string(from: date),
                    hours: entries.reduce(0) { $0 + $1.totalHours },
                    type: primary.type
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// Types présents dans le jeu de données quotidien, dans l'ordre canonique.
    static func orderedTypes(in data: [DailyHoursData]) -> [WorkDayType] {
        let visibleTypes = Set(data.map(\.type))
        return WorkDayType.allCases.filter { visibleTypes.contains($0) }
    }

    /// Répartition des entrées par type (compte + pourcentage), triée par fréquence.
    static func distributionData(from workDays: [WorkDay]) -> [WorkTypeDistribution] {
        let total = workDays.count
        guard total > 0 else { return [] }

        var typeCount: [WorkDayType: Int] = [:]
        for day in workDays {
            typeCount[day.type, default: 0] += 1
        }

        return typeCount.map { type, count in
            WorkTypeDistribution(
                type: type,
                count: count,
                percentage: Double(count) / Double(total) * 100
            )
        }.sorted { $0.count > $1.count }
    }

    /// Résumé statistique de l'année (total, heures sup., jours travaillés, moyenne).
    static func summary(from workDays: [WorkDay]) -> ChartSummary {
        let workedDays = workDays.filter { $0.type == .work }
        let totalHours = workedDays.reduce(0.0) { $0 + $1.totalHours }
        let totalOvertime = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        let workDaysCount = Set(workedDays.map { Calendar.current.startOfDay(for: $0.date) }).count
        let averageHours = workDaysCount > 0 ? totalHours / Double(workDaysCount) : 0

        return ChartSummary(
            totalHours: totalHours,
            overtimeSeconds: totalOvertime,
            workDaysCount: workDaysCount,
            averageHours: averageHours
        )
    }
}
