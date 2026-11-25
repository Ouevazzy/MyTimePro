//
//  PDFService+Data.swift
//  WorkTimer
//
//  Préparation des données et formatage pour les rapports PDF.
//

import Foundation
import UIKit

extension PDFService {
    // MARK: - Data Processing
    
    func getColorForWorkDayType(_ type: WorkDayType, theme: PDFTheme) -> UIColor {
        switch type {
        case .work:
            return theme.primaryColor
        case .vacation, .halfDayVacation:
            return theme.secondaryColor
        case .sickLeave:
            return theme.negativeColor
        case .compensatory:
            return theme.accentColor
        default:
            return theme.textColor
        }
    }
    
    func getColorForIndex(_ index: Int, _ count: Int, theme: PDFTheme) -> UIColor {
        let colors: [UIColor] = [
            theme.primaryColor,
            theme.secondaryColor,
            theme.accentColor,
            theme.negativeColor,
            theme.primaryColor.withAlphaComponent(0.7),
            theme.secondaryColor.withAlphaComponent(0.7),
            theme.accentColor.withAlphaComponent(0.7)
        ]
        
        return colors[index % colors.count]
    }
    
    func calculateStats(_ workDays: [WorkDay], for date: Date = Date(), useDecimalHours: Bool = UserSettings.shared.useDecimalHours, vacationHistory: [WorkDay]? = nil) -> PDFStats {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        let yearWorkDays = workDays.filter { calendar.component(.year, from: $0.date) == year }
        
        let workDaysCount = Set(
            yearWorkDays
                .filter { $0.type == .work }
                .map { calendar.startOfDay(for: $0.date) }
        ).count
        let vacationDays = yearWorkDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        let sickDays = yearWorkDays.filter { $0.type == .sickLeave }.count
        
        var totalHours: Double = 0
        var totalOvertime: Int = 0
        let totalBonus = yearWorkDays.reduce(0.0) { $0 + $1.bonusAmount }
        
        for day in yearWorkDays {
            if day.type == .work {
                totalHours += day.totalHours
            }
            totalOvertime += day.overtimeSeconds
        }
        
        let averageDailyHours = workDaysCount > 0 ? totalHours / Double(workDaysCount) : 0
        
        // Calculer les statistiques complètes de vacances avec report
        // Utiliser TOUS les workDays pour le calcul du report
        let settings = UserSettings.shared
        let entitlement = Double(settings.annualVacationDays)
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        let vacationStatsTuple = VacationCalculations.remainingStats(for: year, workDays: vacationHistory ?? workDays, annualEntitlement: entitlement)
        
        // Pour l'année de début, les droits sont 0 (tout est dans le solde initial / carryIn)
        let annualForDisplay = (year == startYear) ? 0 : entitlement
        let vacationStats = (used: vacationStatsTuple.used, remaining: vacationStatsTuple.remaining, carryIn: vacationStatsTuple.carryIn, annual: annualForDisplay)
        
        return PDFStats(
            workDays: workDaysCount,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            formattedTotalHours: formatHours(totalHours, useDecimal: useDecimalHours),
            overtimeSeconds: totalOvertime,
            formattedOvertimeHours: formatSeconds(totalOvertime, useDecimal: useDecimalHours),
            totalBonus: totalBonus,
            averageDailyHours: averageDailyHours,
            vacationStats: vacationStats
        )
    }
    
    func getMonthlyHoursData(workDays: [WorkDay]) -> [MonthData] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = reportLocale
        dateFormatter.dateFormat = "MMM"
        
        var monthlyHours: [Int: Double] = [:]
        
        for workDay in workDays where workDay.type == .work {
            let month = calendar.component(.month, from: workDay.date)
            monthlyHours[month, default: 0] += workDay.totalHours
        }
        
        var result: [MonthData] = []
        
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2023, month: month, day: 1))!
            result.append(MonthData(
                month: month,
                name: dateFormatter.string(from: date),
                shortName: dateFormatter.string(from: date),
                hours: monthlyHours[month, default: 0],
                overtime: 0
            ))
        }
        
        return result
    }
    
    func getMonthlyOvertimeData(workDays: [WorkDay]) -> [MonthData] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = reportLocale
        dateFormatter.dateFormat = "MMM"
        
        var monthlyOvertime: [Int: Double] = [:]
        
        for workDay in workDays {
            let month = calendar.component(.month, from: workDay.date)
            monthlyOvertime[month, default: 0] += Double(workDay.overtimeSeconds) / 3600.0
        }
        
        var result: [MonthData] = []
        
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2023, month: month, day: 1))!
            result.append(MonthData(
                month: month,
                name: dateFormatter.string(from: date),
                shortName: dateFormatter.string(from: date),
                hours: 0,
                overtime: monthlyOvertime[month, default: 0]
            ))
        }
        
        return result
    }
    
    func getWorkTypeDistribution(workDays: [WorkDay]) -> [TypeDistribution] {
        var typeCount: [WorkDayType: Int] = [:]
        
        let activeWorkDays = workDays
        
        for workDay in activeWorkDays {
            typeCount[workDay.type, default: 0] += 1
        }
        
        let totalDays = activeWorkDays.count
        
        var result: [TypeDistribution] = []
        
        for (type, count) in typeCount where count > 0 {
            result.append(TypeDistribution(
                type: type,
                name: type.localizedName,
                count: count,
                percentage: Double(count) / Double(totalDays)
            ))
        }
        
        return result.sorted { $0.count > $1.count }
    }
    
    // MARK: - Formatting Utils

    /// Langue du rapport : celle de l'app, pour que dates et textes concordent.
    var reportLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "fr")
    }

    /// « 1 jour » / « 3 jours » dans la langue de l'app.
    func daysText(_ count: Int) -> String {
        (count == 1 ? "pdf.days.one" : "pdf.days.other").localized(count)
    }
    
    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = reportLocale
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    func monthName(month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = reportLocale
        return formatter.monthSymbols[month - 1].capitalized
    }
    
    /// Formate des heures en utilisant le paramètre du thème
    func formatHours(_ hours: Double, useDecimal: Bool) -> String {
        if useDecimal {
            return String(format: "%.2f h", hours)
        } else {
            return WorkTimeCalculations.formattedTimeInterval(hours * 3600)
        }
    }
    
    /// Formate des secondes en utilisant le paramètre du thème
    func formatSeconds(_ seconds: Int, useDecimal: Bool) -> String {
        if useDecimal {
            let value = Double(seconds) / 3600.0
            return String(format: "%.2f h", value)
        } else {
            return WorkTimeCalculations.formattedTimeInterval(Double(seconds))
        }
    }
    
    // MARK: - Supporting Structs
    
    struct MonthData {
        let month: Int
        let name: String
        let shortName: String
        let hours: Double
        let overtime: Double
    }
    
    struct TypeDistribution {
        let type: WorkDayType
        let name: String
        let count: Int
        let percentage: Double
    }
}
