import Foundation
import SwiftUI

// MARK: - Stats Cache
/// Cache pour les statistiques calculées afin d'éviter les recalculs répétitifs
@MainActor
@Observable
final class StatsCache {
    static let shared = StatsCache()
    
    // MARK: - Cached Data Types
    struct YearlyStatsCache {
        let year: Int
        let workDays: Int
        let vacationDays: Double
        let sickDays: Int
        let totalHours: Double
        let overtimeSeconds: Int
        let totalBonus: Double
        let timestamp: Date
        
        var isValid: Bool {
            // Le cache est valide pendant 5 minutes
            Date().timeIntervalSince(timestamp) < 300
        }
    }
    
    struct MonthlyStatsCache {
        let year: Int
        let month: Int
        let workDays: Int
        let vacationDays: Double
        let sickDays: Int
        let totalHours: Double
        let overtimeSeconds: Int
        let totalBonus: Double
        let timestamp: Date

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 300
        }
    }
    
    struct VacationStatsCache {
        let year: Int
        let used: Double
        let remaining: Double
        let carryIn: Double
        let annual: Double
        let timestamp: Date
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 300
        }
    }
    
    // MARK: - Cache Storage
    private var yearlyCache: [Int: YearlyStatsCache] = [:]
    private var monthlyCache: [String: MonthlyStatsCache] = [:]
    private var vacationCache: [Int: VacationStatsCache] = [:]
    
    var lastUpdate: Date?

    private let maxEntriesPerCache = 20

    private init() {}
    
    // MARK: - Yearly Stats
    func getYearlyStats(for year: Int) -> YearlyStatsCache? {
        guard let cached = yearlyCache[year], cached.isValid else {
            return nil
        }
        return cached
    }
    
    func cacheYearlyStats(
        year: Int,
        workDays: Int,
        vacationDays: Double,
        sickDays: Int,
        totalHours: Double,
        overtimeSeconds: Int,
        totalBonus: Double
    ) {
        yearlyCache[year] = YearlyStatsCache(
            year: year,
            workDays: workDays,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            overtimeSeconds: overtimeSeconds,
            totalBonus: totalBonus,
            timestamp: Date()
        )
        lastUpdate = Date()

        if yearlyCache.count > maxEntriesPerCache {
            let sortedKeys = yearlyCache.sorted { $0.value.timestamp < $1.value.timestamp }
            for entry in sortedKeys.prefix(yearlyCache.count - maxEntriesPerCache) {
                yearlyCache.removeValue(forKey: entry.key)
            }
        }
    }
    
    // MARK: - Monthly Stats
    func getMonthlyStats(year: Int, month: Int) -> MonthlyStatsCache? {
        let key = "\(year)-\(month)"
        guard let cached = monthlyCache[key], cached.isValid else {
            return nil
        }
        return cached
    }
    
    func cacheMonthlyStats(
        year: Int,
        month: Int,
        workDays: Int,
        vacationDays: Double = 0,
        sickDays: Int = 0,
        totalHours: Double,
        overtimeSeconds: Int,
        totalBonus: Double
    ) {
        let key = "\(year)-\(month)"
        monthlyCache[key] = MonthlyStatsCache(
            year: year,
            month: month,
            workDays: workDays,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            overtimeSeconds: overtimeSeconds,
            totalBonus: totalBonus,
            timestamp: Date()
        )
        lastUpdate = Date()

        if monthlyCache.count > maxEntriesPerCache {
            let sortedKeys = monthlyCache.sorted { $0.value.timestamp < $1.value.timestamp }
            for entry in sortedKeys.prefix(monthlyCache.count - maxEntriesPerCache) {
                monthlyCache.removeValue(forKey: entry.key)
            }
        }
    }
    
    // MARK: - Vacation Stats
    func getVacationStats(for year: Int) -> VacationStatsCache? {
        guard let cached = vacationCache[year], cached.isValid else {
            return nil
        }
        return cached
    }
    
    func cacheVacationStats(
        year: Int,
        used: Double,
        remaining: Double,
        carryIn: Double,
        annual: Double
    ) {
        vacationCache[year] = VacationStatsCache(
            year: year,
            used: used,
            remaining: remaining,
            carryIn: carryIn,
            annual: annual,
            timestamp: Date()
        )
        lastUpdate = Date()

        if vacationCache.count > maxEntriesPerCache {
            let sortedKeys = vacationCache.sorted { $0.value.timestamp < $1.value.timestamp }
            for entry in sortedKeys.prefix(vacationCache.count - maxEntriesPerCache) {
                vacationCache.removeValue(forKey: entry.key)
            }
        }
    }
    
    // MARK: - Cache Management
    func invalidateAll() {
        yearlyCache.removeAll()
        monthlyCache.removeAll()
        vacationCache.removeAll()
        lastUpdate = nil
        AppLogger.debug("Cache invalidé", category: AppLogger.data)
    }
    
    func invalidateYear(_ year: Int) {
        yearlyCache.removeValue(forKey: year)
        vacationCache.removeValue(forKey: year)
        
        // Invalider tous les mois de cette année
        for month in 1...12 {
            let key = "\(year)-\(month)"
            monthlyCache.removeValue(forKey: key)
        }
        lastUpdate = Date()
    }
    
    func invalidateMonth(year: Int, month: Int) {
        let key = "\(year)-\(month)"
        monthlyCache.removeValue(forKey: key)
        yearlyCache.removeValue(forKey: year) // L'annuel doit aussi être recalculé
        lastUpdate = Date()
    }
    
    // MARK: - Statistics
    var cacheInfo: (yearly: Int, monthly: Int, vacation: Int) {
        (yearlyCache.count, monthlyCache.count, vacationCache.count)
    }
    
    var memorySizeEstimate: String {
        let totalEntries = yearlyCache.count + monthlyCache.count + vacationCache.count
        let estimatedBytes = totalEntries * 100 // Estimation grossière
        
        if estimatedBytes < 1024 {
            return "\(estimatedBytes) B"
        } else {
            return "\(estimatedBytes / 1024) KB"
        }
    }
}

// MARK: - Cache-Aware Statistics Calculator
extension StatsCache {
    /// Calcule les statistiques annuelles avec mise en cache
    func calculateYearlyStats(
        for year: Int,
        workDays: [WorkDay],
        forceRefresh: Bool = false
    ) -> YearlyStatsCache {
        // Vérifier le cache
        if !forceRefresh, let cached = getYearlyStats(for: year) {
            return cached
        }
        
        // Calculer
        let calendar = Calendar.current
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == year
        }
        
        let workDaysCount = yearWorkDays.filter { $0.type == .work }.count
        let vacationDays = yearWorkDays.reduce(0.0) { total, day in
            switch day.type {
            case .vacation: return total + 1
            case .halfDayVacation: return total + 0.5
            default: return total
            }
        }
        let sickDays = yearWorkDays.filter { $0.type == .sickLeave }.count
        let totalHours = yearWorkDays.filter { $0.type == .work }.reduce(0.0) { $0 + $1.totalHours }
        let overtimeSeconds = yearWorkDays.reduce(0) { $0 + $1.overtimeSeconds }
        let totalBonus = yearWorkDays.reduce(0.0) { $0 + $1.bonusAmount }
        
        // Mettre en cache
        cacheYearlyStats(
            year: year,
            workDays: workDaysCount,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            overtimeSeconds: overtimeSeconds,
            totalBonus: totalBonus
        )
        
        guard let cached = yearlyCache[year] else {
            return YearlyStatsCache(year: year, workDays: 0, vacationDays: 0, sickDays: 0, totalHours: 0, overtimeSeconds: 0, totalBonus: 0, timestamp: Date())
        }
        return cached
    }
    
    /// Calcule les statistiques mensuelles avec mise en cache
    func calculateMonthlyStats(
        year: Int,
        month: Int,
        workDays: [WorkDay],
        forceRefresh: Bool = false
    ) -> MonthlyStatsCache {
        // Vérifier le cache
        if !forceRefresh, let cached = getMonthlyStats(year: year, month: month) {
            return cached
        }
        
        // Calculer
        let calendar = Calendar.current
        let monthWorkDays = workDays.filter { day in
            let components = calendar.dateComponents([.year, .month], from: day.date)
            return components.year == year && components.month == month
        }

        var workDaysCount = 0; var vacationDays = 0.0; var sickDays = 0
        var totalHours = 0.0; var overtimeSeconds = 0; var totalBonus = 0.0
        for day in monthWorkDays {
            switch day.type {
            case .work:            workDaysCount += 1; totalHours += day.totalHours
            case .vacation:        vacationDays += 1.0
            case .halfDayVacation: vacationDays += 0.5
            case .sickLeave:       sickDays += 1
            default: break
            }
            overtimeSeconds += day.overtimeSeconds
            totalBonus += day.bonusAmount
        }

        // Mettre en cache
        cacheMonthlyStats(
            year: year,
            month: month,
            workDays: workDaysCount,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            overtimeSeconds: overtimeSeconds,
            totalBonus: totalBonus
        )
        
        return monthlyCache["\(year)-\(month)"]!
    }
    
    /// Calcule les statistiques de vacances avec mise en cache
    func calculateVacationStats(
        for year: Int,
        workDays: [WorkDay],
        annualEntitlement: Double,
        forceRefresh: Bool = false
    ) -> VacationStatsCache {
        // Vérifier le cache
        if !forceRefresh, let cached = getVacationStats(for: year) {
            return cached
        }
        
        // Calculer
        let stats = VacationCalculations.remainingStats(
            for: year,
            workDays: workDays,
            annualEntitlement: annualEntitlement
        )
        
        // Mettre en cache
        cacheVacationStats(
            year: year,
            used: stats.used,
            remaining: stats.remaining,
            carryIn: stats.carryIn,
            annual: annualEntitlement
        )
        
        return vacationCache[year]!
    }
}

// MARK: - Observer for Data Changes
extension StatsCache {
    /// Appelé quand les données changent pour invalider le cache pertinent
    func onWorkDayChanged(_ workDay: WorkDay) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: workDay.date)
        let month = calendar.component(.month, from: workDay.date)
        
        invalidateMonth(year: year, month: month)
        
        // Si c'est un congé, invalider aussi le cache des vacances
        if workDay.type == .vacation || workDay.type == .halfDayVacation {
            vacationCache.removeValue(forKey: year)
        }
    }
    
    func onWorkDayDeleted(_ workDay: WorkDay) {
        onWorkDayChanged(workDay)
    }
    
    func onWorkDayAdded(_ workDay: WorkDay) {
        onWorkDayChanged(workDay)
    }
}

