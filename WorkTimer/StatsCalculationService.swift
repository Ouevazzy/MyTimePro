//
//  StatsCalculationService.swift
//  WorkTimer
//
//  Logique d'agrégation des statistiques annuelles/mensuelles, extraite de StatsView.
//  L'agrégation est pure et testable ; l'orchestration du cache est isolée @MainActor.
//

import Foundation

// MARK: - Data Models

struct YearStats {
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double

    static let empty = YearStats(workDays: 0, vacationDays: 0, sickDays: 0,
                                 totalHours: 0, overtimeSeconds: 0, totalBonus: 0)
}

struct MonthStats: Identifiable {
    var id: Int { month }
    let month: Int
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double

    var hasActivity: Bool {
        workDays > 0 ||
        vacationDays > 0 ||
        sickDays > 0 ||
        totalHours != 0 ||
        overtimeSeconds != 0 ||
        totalBonus > 0
    }

    var monthName: String {
        Self.monthSymbols[month - 1]
    }

    private static let monthSymbols: [String] = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        return f.monthSymbols.map { $0.capitalized }
    }()
}

// MARK: - Accumulator

private struct StatsAccumulator {
    var workDates: Set<Date> = []
    var vacationDays = 0.0
    var sickDays = 0
    var totalHours = 0.0
    var overtimeSeconds = 0
    var totalBonus = 0.0

    mutating func add(_ day: WorkDay) {
        switch day.type {
        case .work:
            workDates.insert(Calendar.current.startOfDay(for: day.date))
        case .vacation:
            vacationDays += 1.0
        case .halfDayVacation:
            vacationDays += 0.5
        case .sickLeave:
            sickDays += 1
        default:
            break
        }

        totalHours += day.totalHours
        overtimeSeconds += day.overtimeSeconds
        totalBonus += day.bonusAmount
    }

    var yearStats: YearStats {
        YearStats(workDays: workDates.count,
                  vacationDays: vacationDays,
                  sickDays: sickDays,
                  totalHours: totalHours,
                  overtimeSeconds: overtimeSeconds,
                  totalBonus: totalBonus)
    }

    func monthStats(month: Int) -> MonthStats {
        MonthStats(month: month,
                   workDays: workDates.count,
                   vacationDays: vacationDays,
                   sickDays: sickDays,
                   totalHours: totalHours,
                   overtimeSeconds: overtimeSeconds,
                   totalBonus: totalBonus)
    }
}

// MARK: - Service

enum StatsCalculationService {

    /// Agrégation pure d'une année de `WorkDay` en stats annuelles + 12 mois.
    /// Les entrées supprimées sont ignorées. Aucun effet de bord.
    static func aggregate(days: [WorkDay]) -> (year: YearStats, months: [MonthStats]) {
        var yearlyAccumulator = StatsAccumulator()
        var monthlyAccumulators = Array(repeating: StatsAccumulator(), count: 12)
        let calendar = Calendar.current

        for day in days where !day.isDeleted {
            yearlyAccumulator.add(day)
            let monthIndex = calendar.component(.month, from: day.date) - 1
            if monthlyAccumulators.indices.contains(monthIndex) {
                monthlyAccumulators[monthIndex].add(day)
            }
        }

        let yearStats = yearlyAccumulator.yearStats
        let months = monthlyAccumulators.enumerated().map { index, accumulator in
            accumulator.monthStats(month: index + 1)
        }
        return (yearStats, months)
    }

    /// Renvoie les stats de l'année : depuis le cache si disponible, sinon en
    /// agrégeant les jours fournis par `fetch` (qui injecte l'accès au stockage)
    /// puis en mettant le résultat en cache.
    @MainActor
    static func stats(
        for year: Int,
        fetch: (_ start: Date, _ end: Date) -> [WorkDay]
    ) -> (year: YearStats, months: [MonthStats]) {
        if let cached = cachedStats(for: year) {
            return cached
        }

        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year))!
        let endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!
        let result = aggregate(days: fetch(startDate, endDate))
        store(year: year, result: result)
        return result
    }

    // MARK: - Cache

    @MainActor
    private static func cachedStats(for year: Int) -> (year: YearStats, months: [MonthStats])? {
        let cache = StatsCache.shared
        guard let cachedYear = cache.getYearlyStats(for: year) else {
            return nil
        }

        var months: [MonthStats] = []
        for month in 1...12 {
            guard let cachedMonth = cache.getMonthlyStats(year: year, month: month) else {
                return nil
            }
            months.append(MonthStats(month: month,
                                     workDays: cachedMonth.workDays,
                                     vacationDays: cachedMonth.vacationDays,
                                     sickDays: cachedMonth.sickDays,
                                     totalHours: cachedMonth.totalHours,
                                     overtimeSeconds: cachedMonth.overtimeSeconds,
                                     totalBonus: cachedMonth.totalBonus))
        }

        return (
            YearStats(workDays: cachedYear.workDays,
                      vacationDays: cachedYear.vacationDays,
                      sickDays: cachedYear.sickDays,
                      totalHours: cachedYear.totalHours,
                      overtimeSeconds: cachedYear.overtimeSeconds,
                      totalBonus: cachedYear.totalBonus),
            months
        )
    }

    @MainActor
    private static func store(year: Int, result: (year: YearStats, months: [MonthStats])) {
        let cache = StatsCache.shared
        cache.cacheYearlyStats(year: year,
                               workDays: result.year.workDays,
                               vacationDays: result.year.vacationDays,
                               sickDays: result.year.sickDays,
                               totalHours: result.year.totalHours,
                               overtimeSeconds: result.year.overtimeSeconds,
                               totalBonus: result.year.totalBonus)

        for month in result.months {
            cache.cacheMonthlyStats(year: year,
                                    month: month.month,
                                    workDays: month.workDays,
                                    vacationDays: month.vacationDays,
                                    sickDays: month.sickDays,
                                    totalHours: month.totalHours,
                                    overtimeSeconds: month.overtimeSeconds,
                                    totalBonus: month.totalBonus)
        }
    }
}
