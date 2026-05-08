import Foundation

class WorkTimeCalculations {
    static func calculateTotalHours(startTime: Date, endTime: Date, breakDuration: TimeInterval) -> Double {
        let workedTime = max(0, endTime.timeIntervalSince(startTime) - breakDuration)
        return workedTime / 3600.0 // Convertir les secondes en heures
    }

    static func calculateOvertimeHours(totalHours: Double, standardHours: Double) -> Double {
        return totalHours - standardHours
    }
    
    /// Formate un intervalle de temps en secondes au format hh:mm
    static func formattedTimeInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(round(interval / 60))
        let hours = abs(totalMinutes / 60)
        let minutes = abs(totalMinutes % 60)
        let sign = interval < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }

    // MARK: - Display Formatters
    // Helpers partagés entre HomeTabView, StatsView et WorkDaysListView pour
    // afficher des heures/secondes en respectant le toggle decimal/HH:mm.

    /// Format heures (Double) — arrondi à la minute la plus proche.
    /// Utilisé par HomeTabView et StatsView.
    static func formattedHoursRounded(_ hours: Double) -> String {
        if UserSettings.shared.useDecimalHours {
            return String(format: "%.2f h", hours)
        }
        return formattedTimeInterval(hours * 3600)
    }

    /// Format secondes (Int) — arrondi à la minute la plus proche.
    /// Utilisé par HomeTabView et StatsView.
    static func formattedSecondsRounded(_ seconds: Int) -> String {
        if UserSettings.shared.useDecimalHours {
            return String(format: "%.2f h", Double(seconds) / 3600.0)
        }
        return formattedTimeInterval(Double(seconds))
    }

    /// Format heures (Double) — minutes tronquées (sans arrondi).
    /// Utilisé par WorkDaysListView.MonthlyStatsHeader.
    static func formattedHoursTruncated(_ hours: Double) -> String {
        if UserSettings.shared.useDecimalHours {
            return String(format: "%.2f h", hours)
        }
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%dh%02d", h, m)
    }

    /// Format secondes (Int) — minutes tronquées (sans arrondi).
    /// Utilisé par WorkDaysListView.MonthlyStatsHeader.
    static func formattedSecondsTruncated(_ seconds: Int) -> String {
        if UserSettings.shared.useDecimalHours {
            return String(format: "%.2f h", Double(seconds) / 3600.0)
        }
        let totalMinutes = abs(seconds) / 60
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, h, m)
    }
}

struct VacationCalculations {
    // ✅ Perf: une seule passe for (filtre + accumulation simultanés).
    // Avant: filter() puis reduce() = 2 passes. Après: 1 seule passe.
    static func usedVacationDays(in year: Int, workDays: [WorkDay]) -> Double {
        let calendar = Calendar.current
        var total = 0.0
        for day in workDays {
            guard calendar.component(.year, from: day.date) == year else { continue }
            switch day.type {
            case .vacation:        total += 1.0
            case .halfDayVacation: total += 0.5
            default: break
            }
        }
        return total
    }

    /// Calcule le report (solde d'entrée) pour l'année cible.
    /// Définition: solde disponible au 1er janvier de l'année `year`.
    /// Récurrence: carry(y0) = initial, puis pour chaque année y in [startYear, year-1]
    /// carry(y+1) = max(0, carry(y) + droits(y) - utilise(y))
    static func carryoverDays(for year: Int, workDays: [WorkDay], annualEntitlement: Double) -> Double {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: settings.vacationStartDate)

        // Aucune donnée avant l'année de début
        if year <= startYear {
            // Le report d'entrée pour l'année de début est le solde initial saisi par l'utilisateur
            return settings.initialVacationDays
        }

        // Construire le report en partant de l'année de début jusqu'à l'année précédente
        var carry: Double = settings.initialVacationDays

        for y in startYear..<(year) {
            let usedInYear = usedVacationDays(in: y, workDays: workDays)
            // Pour l'année de début : le solde initial représente TOUT ce qui était disponible
            // (pas de droits supplémentaires à ajouter)
            // Pour les années suivantes : ajouter les droits annuels complets
            let entitlementForYear: Double = (y == startYear) ? 0 : annualEntitlement
            carry = max(0, carry + entitlementForYear - usedInYear)
        }

        return carry
    }
    
    /// Calcule les droits proratisés en fonction de la date de début dans l'année
    static func calculateProRatedEntitlement(startDate: Date, annualEntitlement: Double) -> Double {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: startDate)
        
        // Début et fin de l'année
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return annualEntitlement
        }
        
        // Calculer le nombre de jours restants dans l'année à partir de la date de début
        // Ajouter 1 jour pour inclure le jour de début
        let remainingDays = yearEnd.timeIntervalSince(startDate) + 86400 // +1 jour
        let totalYearDays = yearEnd.timeIntervalSince(yearStart) + 86400 // +1 jour
        
        let proportion = remainingDays / totalYearDays
        return annualEntitlement * proportion
    }

    /// Statistiques pour une année donnée incluant le report depuis les années précédentes.
    static func remainingStats(for year: Int, workDays: [WorkDay], annualEntitlement: Double) -> (used: Double, remaining: Double, carryIn: Double) {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        
        let used = usedVacationDays(in: year, workDays: workDays)
        let carryIn = carryoverDays(for: year, workDays: workDays, annualEntitlement: annualEntitlement)
        
        // Calculer les droits pour l'année en cours
        let currentYearEntitlement: Double
        if year == startYear {
            // Pour l'année de début : le solde initial (carryIn) contient DÉJÀ tout ce qui était disponible
            // Pas de droits supplémentaires à ajouter
            currentYearEntitlement = 0
        } else if year < startYear {
            // Pour les années antérieures à l'année de début, pas de droits
            currentYearEntitlement = 0
        } else {
            // Pour les années après l'année de début, droits complets
            currentYearEntitlement = annualEntitlement
        }
        
        let remaining = max(0, carryIn + currentYearEntitlement - used)
        return (used, remaining, carryIn)
    }
}
