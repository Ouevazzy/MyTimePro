//
//  WorkTimerTests.swift
//  WorkTimerTests
//
//  Created by Jordan Payez on 04.12.2025.
//

import Testing
import Foundation
@testable import WorkTimer

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DES CALCULS D'HEURES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Calculs des heures de travail")
struct WorkHoursTests {
    
    // MARK: - Helpers
    
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }
    
    // MARK: - Tests Heures Totales
    
    @Test("Journée standard 8h00-17h00 avec 1h pause = 8h")
    func journeeStandard() {
        let start = makeDate(year: 2024, month: 6, day: 15, hour: 8, minute: 0)
        let end = makeDate(year: 2024, month: 6, day: 15, hour: 17, minute: 0)
        let breakDuration: TimeInterval = 3600
        
        let totalHours = WorkTimeCalculations.calculateTotalHours(
            startTime: start,
            endTime: end,
            breakDuration: breakDuration
        )
        
        #expect(abs(totalHours - 8.0) < 0.01, "8h00-17h00 avec 1h pause devrait donner 8h")
    }
    
    @Test("Journée longue 7h00-19h00 avec 1h pause = 11h")
    func journeeLongue() {
        let start = makeDate(year: 2024, month: 6, day: 15, hour: 7, minute: 0)
        let end = makeDate(year: 2024, month: 6, day: 15, hour: 19, minute: 0)
        let breakDuration: TimeInterval = 3600
        
        let totalHours = WorkTimeCalculations.calculateTotalHours(
            startTime: start,
            endTime: end,
            breakDuration: breakDuration
        )
        
        #expect(abs(totalHours - 11.0) < 0.01, "7h00-19h00 avec 1h pause devrait donner 11h")
    }
    
    @Test("Demi-journée 8h00-12h30 sans pause = 4h30")
    func demiJournee() {
        let start = makeDate(year: 2024, month: 6, day: 15, hour: 8, minute: 0)
        let end = makeDate(year: 2024, month: 6, day: 15, hour: 12, minute: 30)
        let breakDuration: TimeInterval = 0
        
        let totalHours = WorkTimeCalculations.calculateTotalHours(
            startTime: start,
            endTime: end,
            breakDuration: breakDuration
        )
        
        #expect(abs(totalHours - 4.5) < 0.01, "8h00-12h30 sans pause devrait donner 4h30")
    }
    
    @Test("Journée avec minutes 8h15-17h45 avec 1h pause = 8h30")
    func journeeAvecMinutes() {
        let start = makeDate(year: 2024, month: 6, day: 15, hour: 8, minute: 15)
        let end = makeDate(year: 2024, month: 6, day: 15, hour: 17, minute: 45)
        let breakDuration: TimeInterval = 3600
        
        let totalHours = WorkTimeCalculations.calculateTotalHours(
            startTime: start,
            endTime: end,
            breakDuration: breakDuration
        )
        
        #expect(abs(totalHours - 8.5) < 0.01, "8h15-17h45 avec 1h pause devrait donner 8h30")
    }
    
    @Test("Pause de 2 heures")
    func pauseLongue() {
        let start = makeDate(year: 2024, month: 6, day: 15, hour: 8, minute: 0)
        let end = makeDate(year: 2024, month: 6, day: 15, hour: 18, minute: 0)
        let breakDuration: TimeInterval = 7200 // 2 heures
        
        let totalHours = WorkTimeCalculations.calculateTotalHours(
            startTime: start,
            endTime: end,
            breakDuration: breakDuration
        )
        
        #expect(abs(totalHours - 8.0) < 0.01, "8h00-18h00 avec 2h pause devrait donner 8h")
    }
    
    @Test("Pause de 30 minutes")
    func pauseCourte() {
        let start = makeDate(year: 2024, month: 6, day: 15, hour: 8, minute: 0)
        let end = makeDate(year: 2024, month: 6, day: 15, hour: 16, minute: 30)
        let breakDuration: TimeInterval = 1800 // 30 minutes
        
        let totalHours = WorkTimeCalculations.calculateTotalHours(
            startTime: start,
            endTime: end,
            breakDuration: breakDuration
        )
        
        #expect(abs(totalHours - 8.0) < 0.01, "8h00-16h30 avec 30min pause devrait donner 8h")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DES HEURES SUPPLÉMENTAIRES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Calculs des heures supplémentaires")
struct OvertimeTests {
    
    @Test("Heures supplémentaires positives: 10h - 8h = +2h")
    func heuresPositives() {
        let overtime = WorkTimeCalculations.calculateOvertimeHours(
            totalHours: 10.0,
            standardHours: 8.0
        )
        
        #expect(abs(overtime - 2.0) < 0.01)
    }
    
    @Test("Heures supplémentaires négatives: 6h - 8h = -2h")
    func heuresNegatives() {
        let overtime = WorkTimeCalculations.calculateOvertimeHours(
            totalHours: 6.0,
            standardHours: 8.0
        )
        
        #expect(abs(overtime - (-2.0)) < 0.01)
    }
    
    @Test("Heures supplémentaires exactes: 8h - 8h = 0h")
    func heuresExactes() {
        let overtime = WorkTimeCalculations.calculateOvertimeHours(
            totalHours: 8.0,
            standardHours: 8.0
        )
        
        #expect(abs(overtime) < 0.01)
    }
    
    @Test("Standard non entier: 9h - 8.2h = +0.8h")
    func standardDecimal() {
        let overtime = WorkTimeCalculations.calculateOvertimeHours(
            totalHours: 9.0,
            standardHours: 8.2
        )
        
        #expect(abs(overtime - 0.8) < 0.01)
    }
    
    @Test("Petite différence: 8.25h - 8.2h = +0.05h")
    func petiteDifference() {
        let overtime = WorkTimeCalculations.calculateOvertimeHours(
            totalHours: 8.25,
            standardHours: 8.2
        )
        
        #expect(abs(overtime - 0.05) < 0.01)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DU FORMATAGE DES HEURES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Formatage des heures")
struct FormattingTests {
    
    @Test("Format positif: 7380s = 2h03")
    func formatPositif() {
        let formatted = WorkTimeCalculations.formattedTimeInterval(7380)
        #expect(formatted == "2h03")
    }
    
    @Test("Format négatif: -5400s = -1h30")
    func formatNegatif() {
        let formatted = WorkTimeCalculations.formattedTimeInterval(-5400)
        #expect(formatted == "-1h30")
    }
    
    @Test("Format zéro: 0s = 0h00")
    func formatZero() {
        let formatted = WorkTimeCalculations.formattedTimeInterval(0)
        #expect(formatted == "0h00")
    }
    
    @Test("Format heures pleines: 18000s = 5h00")
    func formatHeuresPleines() {
        let formatted = WorkTimeCalculations.formattedTimeInterval(18000)
        #expect(formatted == "5h00")
    }
    
    @Test("Format grande valeur: 362700s = 100h45")
    func formatGrandeValeur() {
        let formatted = WorkTimeCalculations.formattedTimeInterval(362700)
        #expect(formatted == "100h45")
    }
    
    @Test("Format avec arrondi: 3659s ≈ 1h01")
    func formatArrondi() {
        let formatted = WorkTimeCalculations.formattedTimeInterval(3659)
        #expect(formatted == "1h01")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DES CONGÉS UTILISÉS
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Calculs des congés utilisés")
struct VacationUsedTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType, isDeleted: Bool = false) -> WorkDay {
        let workDay = WorkDay(date: date, type: type)
        workDay.isDeleted = isDeleted
        return workDay
    }
    
    @Test("3 jours de congé complets = 3.0 jours")
    func joursComplets() {
        let workDays = [
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .vacation)
        ]
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used - 3.0) < 0.01)
    }
    
    @Test("4 demi-journées = 2.0 jours")
    func demiJournees() {
        let workDays = [
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .halfDayVacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .halfDayVacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .halfDayVacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 13), type: .halfDayVacation)
        ]
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used - 2.0) < 0.01)
    }
    
    @Test("2 jours + 3 demi-journées = 3.5 jours")
    func mixte() {
        let workDays = [
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .halfDayVacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 13), type: .halfDayVacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 14), type: .halfDayVacation)
        ]
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used - 3.5) < 0.01)
    }
    
    @Test("Entrées supprimées ne sont pas comptées")
    func exclutSupprimes() {
        let workDays = [
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .vacation, isDeleted: false),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .vacation, isDeleted: true),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .vacation, isDeleted: false)
        ]
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used - 2.0) < 0.01, "3 jours dont 1 supprimé = 2 jours comptés")
    }
    
    @Test("Filtre par année correct")
    func filtreParAnnee() {
        let workDays = [
            createWorkDay(date: makeDate(year: 2023, month: 12, day: 20), type: .vacation),
            createWorkDay(date: makeDate(year: 2023, month: 12, day: 21), type: .vacation),
            createWorkDay(date: makeDate(year: 2023, month: 12, day: 22), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 1, day: 2), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 1, day: 3), type: .vacation)
        ]
        
        let used2023 = VacationCalculations.usedVacationDays(in: 2023, workDays: workDays)
        let used2024 = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used2023 - 3.0) < 0.01, "3 jours en 2023")
        #expect(abs(used2024 - 2.0) < 0.01, "2 jours en 2024")
    }
    
    @Test("Ignore les autres types (travail, maladie, férié)")
    func ignoreAutresTypes() {
        let workDays = [
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .vacation),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .work),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .sickLeave),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 13), type: .holiday),
            createWorkDay(date: makeDate(year: 2024, month: 6, day: 14), type: .vacation)
        ]
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used - 2.0) < 0.01, "Seuls les congés comptent")
    }
    
    @Test("Aucune entrée = 0 jours")
    func aucuneEntree() {
        let workDays: [WorkDay] = []
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used) < 0.01)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DU REPORT DE CONGÉS
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Calculs du report de congés")
struct CarryoverTests {
    
    @Test("Scénario utilisateur: 6.7 initial - 5 utilisés = 1.7 reportés")
    func scenarioUtilisateur() {
        let initialDays = 6.7
        let usedIn2023 = 5.0
        let entitlement2023 = 0.0 // Année de début
        
        let carryTo2024 = max(0, initialDays + entitlement2023 - usedIn2023)
        
        #expect(abs(carryTo2024 - 1.7) < 0.01)
    }
    
    @Test("Année suivante: 1.7 report + 25 droits - 10 utilisés = 16.7")
    func anneeSuivante() {
        let carryFrom2023 = 1.7
        let annualEntitlement = 25.0
        let usedIn2024 = 10.0
        
        let carryTo2025 = max(0, carryFrom2023 + annualEntitlement - usedIn2024)
        
        #expect(abs(carryTo2025 - 16.7) < 0.01)
    }
    
    @Test("Calcul sur 4 années")
    func multipleAnnees() {
        let initialDays = 6.7
        let annualEntitlement = 25.0
        
        // 2023 (année de début)
        let usedIn2023 = 5.0
        let carry2024 = max(0, initialDays + 0 - usedIn2023)
        #expect(abs(carry2024 - 1.7) < 0.01, "Report vers 2024")
        
        // 2024
        let usedIn2024 = 10.0
        let carry2025 = max(0, carry2024 + annualEntitlement - usedIn2024)
        #expect(abs(carry2025 - 16.7) < 0.01, "Report vers 2025")
        
        // 2025
        let usedIn2025 = 20.0
        let carry2026 = max(0, carry2025 + annualEntitlement - usedIn2025)
        #expect(abs(carry2026 - 21.7) < 0.01, "Report vers 2026")
        
        // 2026
        let usedIn2026 = 30.0
        let carry2027 = max(0, carry2026 + annualEntitlement - usedIn2026)
        #expect(abs(carry2027 - 16.7) < 0.01, "Report vers 2027")
    }
    
    @Test("Le report ne peut pas être négatif")
    func reportNonNegatif() {
        let initialDays = 5.0
        let used = 10.0
        
        let carry = max(0, initialDays - used)
        
        #expect(carry == 0.0, "Le report est plafonné à 0")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DES STATISTIQUES RESTANTES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Calculs du solde restant")
struct RemainingStatsTests {
    
    @Test("Année de début: 6.7 initial - 3 utilisés = 3.7 restants")
    func anneeDeDebut() {
        let carryIn = 6.7
        let entitlement = 0.0
        let used = 3.0
        
        let remaining = max(0, carryIn + entitlement - used)
        
        #expect(abs(remaining - 3.7) < 0.01)
    }
    
    @Test("Année suivante: 1.7 report + 25 droits - 8 utilisés = 18.7")
    func anneeSuivante() {
        let carryIn = 1.7
        let entitlement = 25.0
        let used = 8.0
        
        let remaining = max(0, carryIn + entitlement - used)
        
        #expect(abs(remaining - 18.7) < 0.01)
    }
    
    @Test("Tous congés utilisés = 0 restant (pas négatif)")
    func tousUtilises() {
        let carryIn = 5.0
        let entitlement = 25.0
        let used = 35.0
        
        let remaining = max(0, carryIn + entitlement - used)
        
        #expect(remaining == 0.0)
    }
    
    @Test("Aucun congé utilisé")
    func aucunUtilise() {
        let carryIn = 5.0
        let entitlement = 25.0
        let used = 0.0
        
        let remaining = max(0, carryIn + entitlement - used)
        
        #expect(abs(remaining - 30.0) < 0.01)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DES DROITS PRORATISÉS
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Calculs des droits proratisés")
struct ProRatedTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    @Test("Début 1er janvier = ~25 jours (année complète)")
    func debutJanvier() {
        let startDate = makeDate(year: 2024, month: 1, day: 1)
        let proRated = VacationCalculations.calculateProRatedEntitlement(
            startDate: startDate,
            annualEntitlement: 25.0
        )
        
        #expect(abs(proRated - 25.0) < 0.5, "Début janvier ≈ année complète")
    }
    
    @Test("Début 1er juillet = ~12.5 jours (moitié d'année)")
    func debutJuillet() {
        let startDate = makeDate(year: 2024, month: 7, day: 1)
        let proRated = VacationCalculations.calculateProRatedEntitlement(
            startDate: startDate,
            annualEntitlement: 25.0
        )
        
        #expect(abs(proRated - 12.5) < 1.0, "Début juillet ≈ moitié d'année")
    }
    
    @Test("Début 1er septembre = ~8.3 jours")
    func debutSeptembre() {
        let startDate = makeDate(year: 2023, month: 9, day: 1)
        let proRated = VacationCalculations.calculateProRatedEntitlement(
            startDate: startDate,
            annualEntitlement: 25.0
        )
        
        #expect(abs(proRated - 8.35) < 1.0, "Début septembre ≈ 1/3 d'année")
    }
    
    @Test("Début 1er décembre = ~2 jours")
    func debutDecembre() {
        let startDate = makeDate(year: 2024, month: 12, day: 1)
        let proRated = VacationCalculations.calculateProRatedEntitlement(
            startDate: startDate,
            annualEntitlement: 25.0
        )
        
        #expect(abs(proRated - 2.1) < 0.5, "Début décembre ≈ 1 mois")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS D'INTÉGRATION
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests d'intégration")
struct IntegrationTests {
    
    @Test("Scénario complet sur 3 ans")
    func scenarioComplet3Ans() {
        let initialDays = 10.0
        let annualEntitlement = 25.0
        
        // 2022 (début)
        let used2022 = 3.0
        let remaining2022 = max(0, initialDays + 0 - used2022)
        #expect(abs(remaining2022 - 7.0) < 0.01, "2022: 10 - 3 = 7")
        
        // 2023
        let carryTo2023 = remaining2022
        let used2023 = 20.0
        let remaining2023 = max(0, carryTo2023 + annualEntitlement - used2023)
        #expect(abs(remaining2023 - 12.0) < 0.01, "2023: 7 + 25 - 20 = 12")
        
        // 2024
        let carryTo2024 = remaining2023
        let used2024 = 15.0
        let remaining2024 = max(0, carryTo2024 + annualEntitlement - used2024)
        #expect(abs(remaining2024 - 22.0) < 0.01, "2024: 12 + 25 - 15 = 22")
    }
    
    @Test("Semaine de travail complète: 5 × 8h = 40h")
    func semaineComplete() {
        // 5 jours de 8h chacun
        let dailyHours = 8.0
        let daysWorked = 5
        
        let totalHours = Double(daysWorked) * dailyHours
        
        #expect(abs(totalHours - 40.0) < 0.01)
    }
    
    @Test("Heures supp. sur une semaine: 5 × (8h - 8.2h) = -1h")
    func overtimeSemaine() {
        let dailyWorked = 8.0
        let dailyStandard = 8.2
        let daysWorked = 5
        
        let weeklyOvertime = Double(daysWorked) * (dailyWorked - dailyStandard)
        
        #expect(abs(weeklyOvertime - (-1.0)) < 0.01)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE CAS LIMITES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Cas limites")
struct EdgeCaseTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    @Test("Aucune entrée de congé = 0 jours")
    func aucuneEntree() {
        let workDays: [WorkDay] = []
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used) < 0.01)
    }
    
    @Test("Toutes entrées supprimées = 0 jours")
    func toutesSupprimes() {
        let workDay1 = WorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .vacation)
        workDay1.isDeleted = true
        let workDay2 = WorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .vacation)
        workDay2.isDeleted = true
        
        let workDays = [workDay1, workDay2]
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used) < 0.01)
    }
    
    @Test("Année sans congés = 0 utilisés")
    func anneeSansConges() {
        let workDay = WorkDay(date: makeDate(year: 2023, month: 6, day: 10), type: .vacation)
        let workDays = [workDay]
        
        // Chercher en 2024 alors que le congé est en 2023
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        #expect(abs(used) < 0.01)
    }
    
    @Test("Valeurs très grandes")
    func valeursGrandes() {
        let carryIn = 100.0
        let entitlement = 50.0
        let used = 30.0
        
        let remaining = max(0, carryIn + entitlement - used)
        
        #expect(abs(remaining - 120.0) < 0.01)
    }
    
    @Test("Valeurs décimales précises")
    func valeursDecimales() {
        let carryIn = 6.73
        let entitlement = 0.0
        let used = 2.5
        
        let remaining = max(0, carryIn + entitlement - used)
        
        #expect(abs(remaining - 4.23) < 0.01)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE VOLUME ET PERFORMANCE (DONNÉES MASSIVES)
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests de volume - 1 année (250 jours)")
struct VolumeTests1Year {
    
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 8, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType, totalHours: Double = 8.0, overtimeSeconds: Int = 0) -> WorkDay {
        let workDay = WorkDay(date: date, type: type)
        workDay.totalHours = totalHours
        workDay.overtimeSeconds = overtimeSeconds
        if type == .work {
            workDay.startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: date)
            workDay.endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: date)
            workDay.breakDuration = 3600
        }
        return workDay
    }
    
    /// Génère une année complète de données réalistes
    /// - Parameter vacationTarget: Nombre de congés à générer (pour tester les reports)
    private func generateYear(year: Int, vacationTarget: Int = 20) -> [WorkDay] {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        var currentDate = makeDate(year: year, month: 1, day: 1)
        let endDate = makeDate(year: year, month: 12, day: 31)
        
        var vacationCount = 0
        var sickCount = 0
        var workDayIndex = 0
        
        // Calculer l'intervalle pour répartir les congés uniformément
        let vacationInterval = max(1, 250 / max(1, vacationTarget))
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Ignorer weekends (1 = dimanche, 7 = samedi)
            if weekday != 1 && weekday != 7 {
                workDayIndex += 1
                
                // Simuler des congés selon le target
                if vacationCount < vacationTarget && workDayIndex % vacationInterval == 0 {
                    workDays.append(createWorkDay(date: currentDate, type: .vacation))
                    vacationCount += 1
                }
                // Simuler des maladies (environ 5 jours/an)
                else if sickCount < 5 && workDayIndex % 50 == 5 {
                    workDays.append(createWorkDay(date: currentDate, type: .sickLeave))
                    sickCount += 1
                }
                // Jours fériés (environ 10/an) - basé sur l'index des jours ouvrés
                else if [1, 20, 45, 65, 90, 110, 140, 180, 200, 230].contains(workDayIndex) {
                    workDays.append(createWorkDay(date: currentDate, type: .holiday))
                }
                // Jours de travail normaux avec variation d'heures
                else {
                    let variation = Double((workDayIndex % 5) - 2) * 0.25 // -0.5 à +0.5h
                    let hours = 8.0 + variation
                    let overtime = Int((hours - 8.2) * 3600)
                    workDays.append(createWorkDay(date: currentDate, type: .work, totalHours: hours, overtimeSeconds: overtime))
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return workDays
    }
    
    @Test("Calcul heures totales sur 250 jours de travail")
    func calculHeures250Jours() {
        let workDays = generateYear(year: 2024)
        let workOnly = workDays.filter { $0.type == .work && !$0.isDeleted }
        
        let totalHours = workOnly.reduce(0.0) { $0 + $1.totalHours }
        
        // ~220 jours de travail × ~8h = ~1760h
        #expect(totalHours > 1500, "Devrait avoir plus de 1500 heures sur l'année")
        #expect(totalHours < 2000, "Devrait avoir moins de 2000 heures sur l'année")
        #expect(workOnly.count > 200, "Devrait avoir plus de 200 jours de travail")
    }
    
    @Test("Calcul heures supplémentaires sur 1 an")
    func calculOvertime1An() {
        let workDays = generateYear(year: 2024)
        let totalOvertime = workDays.filter { !$0.isDeleted }.reduce(0) { $0 + $1.overtimeSeconds }
        
        // Le total peut être positif ou négatif selon les variations
        let overtimeHours = Double(totalOvertime) / 3600.0
        #expect(abs(overtimeHours) < 200, "Overtime devrait être raisonnable sur 1 an")
    }
    
    @Test("Calcul congés utilisés sur 1 an (20 jours)")
    func calculConges1An() {
        let workDays = generateYear(year: 2024, vacationTarget: 20)
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        // La génération crée ~20 congés → report de ~5 jours sur les 25 droits
        #expect(used >= 18 && used <= 22, "Devrait avoir ~20 jours de congés (trouvé: \(used))")
    }
    
    @Test("Filtrage par mois sur données annuelles")
    func filtrageMois() {
        let workDays = generateYear(year: 2024, vacationTarget: 20)
        let calendar = Calendar.current
        
        for month in 1...12 {
            let monthDays = workDays.filter {
                calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == 2024 &&
                !$0.isDeleted
            }
            
            // Chaque mois devrait avoir entre 15 et 25 entrées (jours ouvrés)
            #expect(monthDays.count >= 10, "Mois \(month) devrait avoir au moins 10 jours")
            #expect(monthDays.count <= 25, "Mois \(month) devrait avoir au plus 25 jours")
        }
    }
}

@Suite("Tests de volume - 5 années (~1250 jours)")
struct VolumeTests5Years {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType, totalHours: Double = 8.0, overtimeSeconds: Int = 0) -> WorkDay {
        let workDay = WorkDay(date: date, type: type)
        workDay.totalHours = totalHours
        workDay.overtimeSeconds = overtimeSeconds
        return workDay
    }
    
    /// Génère 5 années de données avec variations pour tester les reports
    /// 2020: 18 congés (report +7), 2021: 22 congés (report +3), 2022: 28 congés (consomme report)
    /// 2023: 20 congés (report +5), 2024: 25 congés (équilibre)
    private func generate5Years() -> [WorkDay] {
        var allWorkDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Variation des congés par année pour tester les reports
        let vacationTargets = [2020: 18, 2021: 22, 2022: 28, 2023: 20, 2024: 25]
        
        for year in 2020...2024 {
            var currentDate = makeDate(year: year, month: 1, day: 1)
            let endDate = makeDate(year: year, month: 12, day: 31)
            
            var vacationCount = 0
            var workDayIndex = 0
            let vacationTarget = vacationTargets[year] ?? 25
            let vacationInterval = max(1, 250 / max(1, vacationTarget))
            
            while currentDate <= endDate {
                let weekday = calendar.component(.weekday, from: currentDate)
                
                if weekday != 1 && weekday != 7 {
                    workDayIndex += 1
                    
                    if vacationCount < vacationTarget && workDayIndex % vacationInterval == 0 {
                        allWorkDays.append(createWorkDay(date: currentDate, type: .vacation))
                        vacationCount += 1
                    } else if workDayIndex % 50 == 5 {
                        allWorkDays.append(createWorkDay(date: currentDate, type: .sickLeave))
                    } else {
                        let hours = 8.0 + Double((workDayIndex % 3) - 1) * 0.3
                        let overtime = Int((hours - 8.2) * 3600)
                        allWorkDays.append(createWorkDay(date: currentDate, type: .work, totalHours: hours, overtimeSeconds: overtime))
                    }
                }
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
        }
        
        return allWorkDays
    }
    
    @Test("Calcul heures totales sur 5 ans (~1250 jours)")
    func calculHeures5Ans() {
        let workDays = generate5Years()
        let workOnly = workDays.filter { $0.type == .work && !$0.isDeleted }
        
        let totalHours = workOnly.reduce(0.0) { $0 + $1.totalHours }
        
        // ~220 jours × 5 ans × ~8h = ~8800h
        #expect(totalHours > 7000, "Devrait avoir plus de 7000 heures sur 5 ans")
        #expect(totalHours < 10000, "Devrait avoir moins de 10000 heures sur 5 ans")
        #expect(workOnly.count > 1000, "Devrait avoir plus de 1000 jours de travail")
    }
    
    @Test("Calcul heures supplémentaires cumulées sur 5 ans")
    func calculOvertimeCumule() {
        let workDays = generate5Years()
        
        var cumulativeOvertime = 0
        for year in 2020...2024 {
            let calendar = Calendar.current
            let yearDays = workDays.filter {
                calendar.component(.year, from: $0.date) == year && !$0.isDeleted
            }
            let yearOvertime = yearDays.reduce(0) { $0 + $1.overtimeSeconds }
            cumulativeOvertime += yearOvertime
        }
        
        let cumulativeHours = Double(cumulativeOvertime) / 3600.0
        // Vérifier que le cumul est calculable et raisonnable
        #expect(abs(cumulativeHours) < 500, "Cumul overtime sur 5 ans devrait être < 500h")
    }
    
    @Test("Calcul congés par année sur 5 ans (variations)")
    func calculCongesParAnnee() {
        let workDays = generate5Years()
        
        // Targets: 2020: 18, 2021: 22, 2022: 28, 2023: 20, 2024: 25
        let expectedRanges: [Int: ClosedRange<Double>] = [
            2020: 16...20,  // ~18
            2021: 20...24,  // ~22
            2022: 26...30,  // ~28
            2023: 18...22,  // ~20
            2024: 23...27   // ~25
        ]
        
        for year in 2020...2024 {
            let used = VacationCalculations.usedVacationDays(in: year, workDays: workDays)
            let range = expectedRanges[year]!
            #expect(range.contains(used), "Année \(year): attendu \(range), trouvé \(used)")
        }
    }
    
    @Test("Report de congés sur 5 ans (accumulation et consommation)")
    func reportConges5Ans() {
        let workDays = generate5Years()
        let annualEntitlement = 25.0
        
        // Début 2020 avec solde initial de 10 jours
        let initialDays = 10.0
        var carry = initialDays
        
        // Suivre l'évolution du solde année par année
        var balanceHistory: [(year: Int, carryIn: Double, entitlement: Double, used: Double, remaining: Double)] = []
        
        for year in 2020...2024 {
            let used = VacationCalculations.usedVacationDays(in: year, workDays: workDays)
            let entitlement = (year == 2020) ? 0 : annualEntitlement
            let available = carry + entitlement
            let remaining = max(0, available - used)
            
            balanceHistory.append((year, carry, entitlement, used, remaining))
            
            // Le solde ne doit jamais être négatif
            #expect(remaining >= 0, "Solde \(year) >= 0 (report=\(carry) + droits=\(entitlement) - utilisés=\(used) = \(remaining))")
            
            // Vérifier la formule de calcul
            let expectedRemaining = max(0, carry + entitlement - used)
            #expect(abs(remaining - expectedRemaining) < 0.01, "Formule correcte pour \(year)")
            
            // Vérifier la logique d'accumulation/consommation
            if year > 2020 {
                let netChange = entitlement - used  // Positif = accumulation, négatif = consommation
                if netChange > 0 {
                    // Accumulation : le solde augmente par rapport au carry d'entrée
                    #expect(remaining > carry, "Année \(year): accumulation (used=\(used) < droits=\(entitlement)), solde \(carry) → \(remaining)")
                } else if netChange < 0 {
                    // Consommation : le solde diminue (utilise le report)
                    #expect(remaining < carry + entitlement, "Année \(year): consommation du report")
                }
            }
            
            carry = remaining
        }
        
        // Afficher l'historique pour debug
        #expect(balanceHistory.count == 5, "5 années traitées")
    }
}

@Suite("Tests de volume - 10 années (~2500 jours)")
struct VolumeTests10Years {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType, totalHours: Double = 8.0, overtimeSeconds: Int = 0) -> WorkDay {
        let workDay = WorkDay(date: date, type: type)
        workDay.totalHours = totalHours
        workDay.overtimeSeconds = overtimeSeconds
        return workDay
    }
    
    /// Génère 10 années de données avec variations pour tester les reports
    private func generate10Years() -> [WorkDay] {
        var allWorkDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Variations réalistes : certaines années on utilise moins, d'autres plus
        let vacationTargets = [
            2015: 20, 2016: 23, 2017: 18, 2018: 26, 2019: 22,
            2020: 19, 2021: 24, 2022: 21, 2023: 27, 2024: 20
        ]
        
        for year in 2015...2024 {
            var currentDate = makeDate(year: year, month: 1, day: 1)
            let endDate = makeDate(year: year, month: 12, day: 31)
            
            var vacationCount = 0
            var workDayIndex = 0
            let vacationTarget = vacationTargets[year] ?? 22
            let vacationInterval = max(1, 250 / max(1, vacationTarget))
            
            while currentDate <= endDate {
                let weekday = calendar.component(.weekday, from: currentDate)
                
                if weekday != 1 && weekday != 7 {
                    workDayIndex += 1
                    
                    if vacationCount < vacationTarget && workDayIndex % vacationInterval == 0 {
                        allWorkDays.append(createWorkDay(date: currentDate, type: .vacation))
                        vacationCount += 1
                    } else {
                        let hours = 8.0 + Double((workDayIndex % 5) - 2) * 0.2
                        let overtime = Int((hours - 8.2) * 3600)
                        allWorkDays.append(createWorkDay(date: currentDate, type: .work, totalHours: hours, overtimeSeconds: overtime))
                    }
                }
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
        }
        
        return allWorkDays
    }
    
    @Test("Calcul heures totales sur 10 ans (~2500 jours)")
    func calculHeures10Ans() {
        let workDays = generate10Years()
        let workOnly = workDays.filter { $0.type == .work && !$0.isDeleted }
        
        let totalHours = workOnly.reduce(0.0) { $0 + $1.totalHours }
        
        // ~220 jours × 10 ans × ~8h = ~17600h
        #expect(totalHours > 15000, "Devrait avoir plus de 15000 heures sur 10 ans")
        #expect(totalHours < 20000, "Devrait avoir moins de 20000 heures sur 10 ans")
        #expect(workOnly.count > 2000, "Devrait avoir plus de 2000 jours de travail")
    }
    
    @Test("Nombre total d'entrées sur 10 ans")
    func nombreEntrees10Ans() {
        let workDays = generate10Years()
        
        #expect(workDays.count > 2400, "Devrait avoir plus de 2400 entrées sur 10 ans")
        #expect(workDays.count < 2700, "Devrait avoir moins de 2700 entrées sur 10 ans")
    }
    
    @Test("Calcul congés cumulés sur 10 ans")
    func calculCongesCumules10Ans() {
        let workDays = generate10Years()
        
        var totalVacation = 0.0
        for year in 2015...2024 {
            let used = VacationCalculations.usedVacationDays(in: year, workDays: workDays)
            totalVacation += used
        }
        
        // Moyenne ~22 jours × 10 ans = ~220 jours
        // Targets: 20+23+18+26+22+19+24+21+27+20 = 220
        #expect(totalVacation > 180, "Devrait avoir plus de 180 jours de congés sur 10 ans")
        #expect(totalVacation < 260, "Devrait avoir moins de 260 jours de congés sur 10 ans")
    }
    
    @Test("Report progressif sur 10 ans avec variations")
    func reportProgressif10Ans() {
        let workDays = generate10Years()
        let annualEntitlement = 25.0
        let initialDays = 10.0  // Solde initial réaliste
        
        var carry = initialDays
        var allRemainings: [Double] = []
        var yearlyDetails: [(year: Int, used: Double, entitlement: Double, remaining: Double)] = []
        
        for year in 2015...2024 {
            let used = VacationCalculations.usedVacationDays(in: year, workDays: workDays)
            let entitlement = (year == 2015) ? 0 : annualEntitlement
            let remaining = max(0, carry + entitlement - used)
            
            yearlyDetails.append((year, used, entitlement, remaining))
            allRemainings.append(remaining)
            #expect(remaining >= 0, "Solde \(year) ne doit pas être négatif (carry=\(carry), ent=\(entitlement), used=\(used))")
            
            carry = remaining
        }
        
        // Vérifier qu'on a bien 10 valeurs
        #expect(allRemainings.count == 10)
        
        // Vérifier que le solde final est cohérent
        // Initial: 10, puis 9 ans × 25 droits = 225, total utilisé ~220
        // Solde final devrait être autour de 10 + 225 - 220 = ~15
        let finalBalance = allRemainings.last ?? 0
        #expect(finalBalance > 0, "Solde final devrait être positif")
        #expect(finalBalance < 50, "Solde final ne devrait pas exploser")
    }
}

@Suite("Tests de stress - Données extrêmes")
struct StressTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType) -> WorkDay {
        WorkDay(date: date, type: type)
    }
    
    @Test("5000 entrées - calcul heures")
    func stress5000Entrees() {
        var workDays: [WorkDay] = []
        let baseDate = makeDate(year: 2010, month: 1, day: 1)
        
        for i in 0..<5000 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: baseDate)!
            let workDay = createWorkDay(date: date, type: .work)
            workDay.totalHours = 8.0
            workDay.overtimeSeconds = Int.random(in: -3600...3600)
            workDays.append(workDay)
        }
        
        let totalHours = workDays.reduce(0.0) { $0 + $1.totalHours }
        let totalOvertime = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        
        #expect(abs(totalHours - 40000.0) < 1.0, "5000 × 8h = 40000h")
        #expect(abs(totalOvertime) < 5000 * 3600, "Overtime dans les limites")
    }
    
    @Test("10000 entrées - calcul congés")
    func stress10000Entrees() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        for year in 2000...2024 {
            for dayOfYear in 1...365 {
                var components = DateComponents()
                components.year = year
                components.day = dayOfYear
                if let date = calendar.date(from: components) {
                    // 1 congé tous les 15 jours
                    let type: WorkDayType = (dayOfYear % 15 == 0) ? .vacation : .work
                    workDays.append(createWorkDay(date: date, type: type))
                }
            }
        }
        
        // Calcul des congés pour chaque année
        for year in 2000...2024 {
            let used = VacationCalculations.usedVacationDays(in: year, workDays: workDays)
            #expect(used > 20, "Année \(year) devrait avoir > 20 congés")
            #expect(used < 30, "Année \(year) devrait avoir < 30 congés")
        }
    }
    
    @Test("Mélange types avec entrées supprimées")
    func stressMelangeTypes() {
        var workDays: [WorkDay] = []
        let baseDate = makeDate(year: 2024, month: 1, day: 1)
        
        for i in 0..<1000 {
            let date = Calendar.current.date(byAdding: .day, value: i % 365, to: baseDate)!
            let types: [WorkDayType] = [.work, .vacation, .halfDayVacation, .sickLeave, .holiday, .compensatory]
            let type = types[i % types.count]
            let workDay = createWorkDay(date: date, type: type)
            
            // 10% des entrées sont supprimées
            if i % 10 == 0 {
                workDay.isDeleted = true
            }
            
            workDay.totalHours = (type == .work) ? 8.0 : 0.0
            workDays.append(workDay)
        }
        
        // Les entrées supprimées ne doivent pas être comptées
        let activeWorkDays = workDays.filter { !$0.isDeleted }
        let deletedCount = workDays.filter { $0.isDeleted }.count
        
        #expect(deletedCount == 100, "10% de 1000 = 100 supprimées")
        #expect(activeWorkDays.count == 900, "900 actives restantes")
        
        // Calcul des heures uniquement sur les actives
        let totalHours = activeWorkDays.filter { $0.type == .work }.reduce(0.0) { $0 + $1.totalHours }
        #expect(totalHours > 0, "Devrait avoir des heures de travail")
    }
    
    @Test("Report sur 20 ans")
    func stressReport20Ans() {
        let annualEntitlement = 25.0
        let initialDays = 10.0
        var carry = initialDays
        
        for year in 2005...2024 {
            // Simuler utilisation variable (20-30 jours)
            let used = Double(20 + (year % 11))
            let entitlement = (year == 2005) ? 0 : annualEntitlement
            let remaining = max(0, carry + entitlement - used)
            
            #expect(remaining >= 0, "Solde \(year) >= 0")
            carry = remaining
        }
        
        // Après 20 ans, le solde devrait être positif (si utilisé < droits)
        #expect(carry >= 0, "Solde final >= 0")
    }
    
    @Test("Calcul avec valeurs décimales précises")
    func stressDecimales() {
        var total = 0.0
        
        // 10000 additions de valeurs décimales
        for i in 0..<10000 {
            let value = Double(i % 100) / 100.0 + 7.5 // 7.50 à 8.49
            total += value
        }
        
        // Vérifier la précision du calcul
        let expected = 79950.0 // Somme approximative
        #expect(abs(total - expected) < 100, "Précision décimale maintenue")
    }
    
    @Test("Filtrage rapide sur grande quantité")
    func stressFiltrage() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Générer 3000 entrées sur plusieurs années
        for year in 2020...2024 {
            for month in 1...12 {
                for day in 1...28 {
                    let date = makeDate(year: year, month: month, day: day)
                    let types: [WorkDayType] = [.work, .work, .work, .work, .vacation]
                    let type = types[(year + month + day) % types.count]
                    workDays.append(createWorkDay(date: date, type: type))
                }
            }
        }
        
        // Test de filtrage par année
        for year in 2020...2024 {
            let yearDays = workDays.filter {
                calendar.component(.year, from: $0.date) == year && !$0.isDeleted
            }
            #expect(yearDays.count > 300, "Année \(year) devrait avoir > 300 entrées")
        }
        
        // Test de filtrage par mois
        let jan2024 = workDays.filter {
            calendar.component(.year, from: $0.date) == 2024 &&
            calendar.component(.month, from: $0.date) == 1 &&
            !$0.isDeleted
        }
        #expect(jan2024.count == 28, "Janvier 2024 devrait avoir 28 entrées")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE PERFORMANCE
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests de performance")
struct PerformanceTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType) -> WorkDay {
        let workDay = WorkDay(date: date, type: type)
        workDay.totalHours = 8.0
        workDay.overtimeSeconds = Int.random(in: -1800...1800)
        return workDay
    }
    
    @Test("Calcul 1000 entrées en < 50ms")
    func performance1000Entrees() {
        var workDays: [WorkDay] = []
        let baseDate = makeDate(year: 2024, month: 1, day: 1)
        
        for i in 0..<1000 {
            let date = Calendar.current.date(byAdding: .day, value: i % 365, to: baseDate)!
            workDays.append(createWorkDay(date: date, type: .work))
        }
        
        let start = Date()
        let _ = workDays.reduce(0.0) { $0 + $1.totalHours }
        let _ = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        let elapsed = Date().timeIntervalSince(start)
        
        #expect(elapsed < 0.05, "1000 entrées devrait prendre < 50ms (trouvé: \(elapsed * 1000)ms)")
    }
    
    @Test("Calcul 5000 entrées en < 200ms")
    func performance5000Entrees() {
        var workDays: [WorkDay] = []
        let baseDate = makeDate(year: 2020, month: 1, day: 1)
        
        for i in 0..<5000 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: baseDate)!
            workDays.append(createWorkDay(date: date, type: i % 10 == 0 ? .vacation : .work))
        }
        
        let start = Date()
        
        // Simuler les calculs réels de l'app
        let totalHours = workDays.filter { $0.type == .work && !$0.isDeleted }.reduce(0.0) { $0 + $1.totalHours }
        let totalOvertime = workDays.filter { !$0.isDeleted }.reduce(0) { $0 + $1.overtimeSeconds }
        let vacationDays = workDays.filter { ($0.type == .vacation || $0.type == .halfDayVacation) && !$0.isDeleted }.count
        
        let elapsed = Date().timeIntervalSince(start)
        
        #expect(elapsed < 0.2, "5000 entrées devrait prendre < 200ms (trouvé: \(elapsed * 1000)ms)")
        #expect(totalHours > 0, "Heures calculées")
        #expect(vacationDays > 0, "Congés comptés")
        _ = totalOvertime // Utilisé
    }
    
    @Test("Filtrage par année sur 10000 entrées en < 500ms")
    func performanceFiltrage() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        for year in 2015...2024 {
            for dayOfYear in 1...365 {
                var components = DateComponents()
                components.year = year
                components.day = dayOfYear
                if let date = calendar.date(from: components) {
                    workDays.append(createWorkDay(date: date, type: .work))
                }
            }
        }
        
        let start = Date()
        
        // Filtrer par année (opération fréquente)
        var totalFiltered = 0
        for year in 2015...2024 {
            let filtered = workDays.filter {
                calendar.component(.year, from: $0.date) == year && !$0.isDeleted
            }
            totalFiltered += filtered.count
        }
        
        let elapsed = Date().timeIntervalSince(start)
        
        // Tolérance large pour le simulateur iOS (plus lent qu'un vrai appareil)
        #expect(elapsed < 0.5, "Filtrage 10 ans devrait prendre < 500ms (trouvé: \(elapsed * 1000)ms)")
        #expect(totalFiltered > 3000, "Devrait avoir filtré des entrées")
    }
    
    @Test("Calcul report sur 30 ans en < 10ms")
    func performanceReport30Ans() {
        let start = Date()
        
        let annualEntitlement = 25.0
        var carry = 10.0
        
        for year in 1995...2024 {
            let used = Double(18 + (year % 10))
            let entitlement = (year == 1995) ? 0 : annualEntitlement
            carry = max(0, carry + entitlement - used)
        }
        
        let elapsed = Date().timeIntervalSince(start)
        
        #expect(elapsed < 0.01, "Report 30 ans devrait prendre < 10ms (trouvé: \(elapsed * 1000)ms)")
        #expect(carry >= 0, "Solde final valide")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DU MODÈLE WORKDAY
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests du modèle WorkDay")
struct WorkDayModelTests {
    
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 8, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
    
    @Test("Création WorkDay avec valeurs par défaut")
    func creationDefaut() {
        let date = makeDate(year: 2024, month: 6, day: 15)
        let workDay = WorkDay(date: date, type: .work)
        
        #expect(workDay.type == .work)
        #expect(workDay.totalHours == 0)
        #expect(workDay.overtimeSeconds == 0)
        #expect(workDay.isDeleted == false)
        #expect(workDay.bonusAmount == 0)
    }
    
    @Test("WorkDay type congé")
    func typeConge() {
        let date = makeDate(year: 2024, month: 8, day: 1)
        let vacation = WorkDay(date: date, type: .vacation)
        let halfDay = WorkDay(date: date, type: .halfDayVacation)
        
        #expect(vacation.type == .vacation)
        #expect(halfDay.type == .halfDayVacation)
    }
    
    @Test("WorkDay avec heures et overtime")
    func heuresEtOvertime() {
        let date = makeDate(year: 2024, month: 6, day: 15)
        let workDay = WorkDay(date: date, type: .work)
        workDay.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 8, minute: 0)
        workDay.endTime = makeDate(year: 2024, month: 6, day: 15, hour: 18, minute: 0)
        workDay.breakDuration = 3600  // 1h de pause
        workDay.totalHours = 9.0
        workDay.overtimeSeconds = 2880  // +0.8h = 48min
        
        #expect(workDay.totalHours == 9.0)
        #expect(workDay.overtimeSeconds == 2880)
    }
    
    @Test("WorkDay marqué comme supprimé")
    func marqueSupprimer() {
        let date = makeDate(year: 2024, month: 6, day: 15)
        let workDay = WorkDay(date: date, type: .work)
        workDay.totalHours = 8.0
        
        #expect(workDay.isDeleted == false)
        
        workDay.isDeleted = true
        
        #expect(workDay.isDeleted == true)
        #expect(workDay.totalHours == 8.0)  // Les données restent mais marquées
    }
    
    @Test("WorkDay avec bonus")
    func avecBonus() {
        let date = makeDate(year: 2024, month: 12, day: 25)
        let workDay = WorkDay(date: date, type: .work)
        workDay.bonusAmount = 50.0
        workDay.note = "Jour férié travaillé"
        
        #expect(workDay.bonusAmount == 50.0)
        #expect(workDay.note == "Jour férié travaillé")
    }
    
    @Test("Tous les types de WorkDay")
    func tousLesTypes() {
        let date = makeDate(year: 2024, month: 6, day: 15)
        
        let types: [WorkDayType] = [.work, .vacation, .halfDayVacation, .sickLeave, .holiday, .compensatory]
        
        for type in types {
            let workDay = WorkDay(date: date, type: type)
            #expect(workDay.type == type, "Type \(type) créé correctement")
        }
        
        #expect(types.count == 6, "6 types de WorkDay supportés")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE DATES SPÉCIALES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests de dates spéciales")
struct SpecialDatesTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, type: WorkDayType) -> WorkDay {
        WorkDay(date: date, type: type)
    }
    
    @Test("Année bissextile 2024 - 29 février")
    func anneeBissextile() {
        let feb29 = makeDate(year: 2024, month: 2, day: 29)
        let workDay = createWorkDay(date: feb29, type: .work)
        workDay.totalHours = 8.0
        
        let calendar = Calendar.current
        #expect(calendar.component(.day, from: workDay.date) == 29)
        #expect(calendar.component(.month, from: workDay.date) == 2)
        #expect(calendar.component(.year, from: workDay.date) == 2024)
    }
    
    @Test("Fin d'année - 31 décembre")
    func finAnnee() {
        let dec31 = makeDate(year: 2024, month: 12, day: 31)
        let workDay = createWorkDay(date: dec31, type: .work)
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: workDay.date)
        
        #expect(year == 2024)
    }
    
    @Test("Début d'année - 1er janvier")
    func debutAnnee() {
        let jan1 = makeDate(year: 2025, month: 1, day: 1)
        let workDay = createWorkDay(date: jan1, type: .holiday)
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: workDay.date)
        
        #expect(year == 2025)
        #expect(workDay.type == .holiday)
    }
    
    @Test("Transition d'année dans les calculs")
    func transitionAnnee() {
        var workDays: [WorkDay] = []
        
        // Derniers jours de 2024
        for day in 28...31 {
            let date = makeDate(year: 2024, month: 12, day: day)
            workDays.append(createWorkDay(date: date, type: .work))
        }
        
        // Premiers jours de 2025
        for day in 1...5 {
            let date = makeDate(year: 2025, month: 1, day: day)
            workDays.append(createWorkDay(date: date, type: .work))
        }
        
        let calendar = Calendar.current
        let days2024 = workDays.filter { calendar.component(.year, from: $0.date) == 2024 }
        let days2025 = workDays.filter { calendar.component(.year, from: $0.date) == 2025 }
        
        #expect(days2024.count == 4, "4 jours en 2024")
        #expect(days2025.count == 5, "5 jours en 2025")
    }
    
    @Test("Congés sur plusieurs années")
    func congesPlusieursAnnees() {
        var workDays: [WorkDay] = []
        
        // Congé fin 2024
        workDays.append(createWorkDay(date: makeDate(year: 2024, month: 12, day: 30), type: .vacation))
        workDays.append(createWorkDay(date: makeDate(year: 2024, month: 12, day: 31), type: .vacation))
        
        // Congé début 2025
        workDays.append(createWorkDay(date: makeDate(year: 2025, month: 1, day: 2), type: .vacation))
        workDays.append(createWorkDay(date: makeDate(year: 2025, month: 1, day: 3), type: .vacation))
        
        let used2024 = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        let used2025 = VacationCalculations.usedVacationDays(in: 2025, workDays: workDays)
        
        #expect(abs(used2024 - 2.0) < 0.01, "2 jours en 2024")
        #expect(abs(used2025 - 2.0) < 0.01, "2 jours en 2025")
    }
    
    @Test("Mois de février non bissextile")
    func fevrierNonBissextile() {
        // 2023 n'est pas bissextile
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2023
        components.month = 2
        
        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: components)!)!
        
        #expect(range.count == 28, "Février 2023 a 28 jours")
    }
    
    @Test("Mois de février bissextile")
    func fevrierBissextile() {
        // 2024 est bissextile
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        
        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: components)!)!
        
        #expect(range.count == 29, "Février 2024 a 29 jours")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE COHÉRENCE DES DONNÉES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests de cohérence des données")
struct DataConsistencyTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    @Test("Cohérence heures totales vs overtime")
    func coherenceHeuresOvertime() {
        let standardHours = 8.2
        
        // Cas 1: Journée exacte
        let exact = 8.2
        let overtimeExact = Int((exact - standardHours) * 3600)
        #expect(overtimeExact == 0, "8.2h - 8.2h = 0 overtime")
        
        // Cas 2: Journée longue
        let long = 10.0
        let overtimeLong = Int((long - standardHours) * 3600)
        #expect(overtimeLong == 6480, "10h - 8.2h = 1.8h = 6480s")
        
        // Cas 3: Journée courte (avec tolérance pour arrondi flottant)
        let short = 6.0
        let overtimeShort = Int((short - standardHours) * 3600)
        // -2.2h = -7920s, mais arrondi flottant peut donner -7919 ou -7920
        #expect(abs(overtimeShort - (-7920)) <= 1, "6h - 8.2h = -2.2h ≈ -7920s (trouvé: \(overtimeShort))")
    }
    
    @Test("Cohérence congés complets vs demi-journées")
    func coherenceConges() {
        var workDays: [WorkDay] = []
        
        // 2 congés complets
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .vacation))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .vacation))
        
        // 4 demi-journées = 2 jours
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .halfDayVacation))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 13), type: .halfDayVacation))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 14), type: .halfDayVacation))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 17), type: .halfDayVacation))
        
        let used = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        // 2 complets + 4 × 0.5 = 2 + 2 = 4 jours
        #expect(abs(used - 4.0) < 0.01, "2 complets + 4 demi = 4 jours")
    }
    
    @Test("Cohérence après suppression")
    func coherenceApresSupression() {
        var workDays: [WorkDay] = []
        
        // Ajouter 5 jours de congé
        for day in 1...5 {
            workDays.append(WorkDay(date: makeDate(year: 2024, month: 7, day: day), type: .vacation))
        }
        
        let usedBefore = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        #expect(abs(usedBefore - 5.0) < 0.01, "5 jours avant suppression")
        
        // Supprimer 2 jours
        workDays[0].isDeleted = true
        workDays[1].isDeleted = true
        
        let usedAfter = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        #expect(abs(usedAfter - 3.0) < 0.01, "3 jours après suppression de 2")
    }
    
    @Test("Cohérence cumul overtime")
    func coherenceCumulOvertime() {
        var totalOvertime = 0
        
        // Simuler une semaine
        let dailyOvertimes = [1800, -900, 0, 2700, -1800]  // en secondes
        
        for overtime in dailyOvertimes {
            totalOvertime += overtime
        }
        
        let expectedTotal = 1800 - 900 + 0 + 2700 - 1800  // = 1800s = 30min
        #expect(totalOvertime == expectedTotal, "Cumul overtime correct")
        #expect(totalOvertime == 1800, "30 minutes de surplus sur la semaine")
    }
    
    @Test("Cohérence entre mois et année")
    func coherenceMoisAnnee() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Générer des congés sur tous les mois
        for month in 1...12 {
            let day = min(15, 28)  // Jour sûr pour tous les mois
            workDays.append(WorkDay(date: makeDate(year: 2024, month: month, day: day), type: .vacation))
        }
        
        // Total année
        let yearTotal = VacationCalculations.usedVacationDays(in: 2024, workDays: workDays)
        
        // Total par mois
        var monthsTotal = 0.0
        for month in 1...12 {
            let monthDays = workDays.filter {
                calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == 2024
            }
            monthsTotal += Double(monthDays.filter { $0.type == .vacation }.count)
        }
        
        #expect(abs(yearTotal - monthsTotal) < 0.01, "Total année = somme des mois")
        #expect(abs(yearTotal - 12.0) < 0.01, "12 congés dans l'année")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE FILTRAGE ET TRI
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests de filtrage et tri")
struct FilteringSortingTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    @Test("Filtrage par type de journée")
    func filtrageParType() {
        var workDays: [WorkDay] = []
        
        // Créer un mix de types
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 1), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 2), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 3), type: .vacation))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 4), type: .sickLeave))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 5), type: .holiday))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 6), type: .work))
        
        let workOnly = workDays.filter { $0.type == .work }
        let vacationOnly = workDays.filter { $0.type == .vacation }
        let sickOnly = workDays.filter { $0.type == .sickLeave }
        let holidayOnly = workDays.filter { $0.type == .holiday }
        
        #expect(workOnly.count == 3, "3 jours de travail")
        #expect(vacationOnly.count == 1, "1 jour de congé")
        #expect(sickOnly.count == 1, "1 jour de maladie")
        #expect(holidayOnly.count == 1, "1 jour férié")
    }
    
    @Test("Filtrage par période (mois)")
    func filtrageParMois() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Entrées sur 3 mois
        for month in 4...6 {
            for day in 1...10 {
                workDays.append(WorkDay(date: makeDate(year: 2024, month: month, day: day), type: .work))
            }
        }
        
        let may2024 = workDays.filter {
            calendar.component(.month, from: $0.date) == 5 &&
            calendar.component(.year, from: $0.date) == 2024
        }
        
        #expect(may2024.count == 10, "10 entrées en mai 2024")
    }
    
    @Test("Filtrage excluant les supprimés")
    func filtrageExcluantSupprimes() {
        var workDays: [WorkDay] = []
        
        for day in 1...10 {
            let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: day), type: .work)
            if day % 3 == 0 {
                wd.isDeleted = true
            }
            workDays.append(wd)
        }
        
        let active = workDays.filter { !$0.isDeleted }
        let deleted = workDays.filter { $0.isDeleted }
        
        #expect(active.count == 7, "7 entrées actives")
        #expect(deleted.count == 3, "3 entrées supprimées (jours 3, 6, 9)")
    }
    
    @Test("Tri par date croissant")
    func triDateCroissant() {
        var workDays: [WorkDay] = []
        
        // Ajouter dans le désordre
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 5), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 25), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .work))
        
        let sorted = workDays.sorted { $0.date < $1.date }
        
        let calendar = Calendar.current
        let days = sorted.map { calendar.component(.day, from: $0.date) }
        
        #expect(days == [5, 10, 15, 25], "Trié par date croissante")
    }
    
    @Test("Tri par date décroissant")
    func triDateDecroissant() {
        var workDays: [WorkDay] = []
        
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 5), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 25), type: .work))
        workDays.append(WorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .work))
        
        let sorted = workDays.sorted { $0.date > $1.date }
        
        let calendar = Calendar.current
        let days = sorted.map { calendar.component(.day, from: $0.date) }
        
        #expect(days == [25, 15, 10, 5], "Trié par date décroissante")
    }
    
    @Test("Filtrage combiné (type + période + actif)")
    func filtrageCombine() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Générer des données variées
        for month in 1...3 {
            for day in 1...5 {
                let types: [WorkDayType] = [.work, .vacation, .work, .sickLeave, .work]
                let wd = WorkDay(date: makeDate(year: 2024, month: month, day: day), type: types[day - 1])
                if day == 3 { wd.isDeleted = true }
                workDays.append(wd)
            }
        }
        
        // Filtrer: travail + février + actif
        let result = workDays.filter {
            $0.type == .work &&
            calendar.component(.month, from: $0.date) == 2 &&
            !$0.isDeleted
        }
        
        // Jours 1, 3, 5 sont .work, mais jour 3 est supprimé → 2 résultats
        #expect(result.count == 2, "2 jours de travail actifs en février")
    }
    
    @Test("Recherche par note")
    func rechercheParNote() {
        var workDays: [WorkDay] = []
        
        let wd1 = WorkDay(date: makeDate(year: 2024, month: 6, day: 1), type: .work)
        wd1.note = "Réunion importante"
        
        let wd2 = WorkDay(date: makeDate(year: 2024, month: 6, day: 2), type: .work)
        wd2.note = "Formation équipe"
        
        let wd3 = WorkDay(date: makeDate(year: 2024, month: 6, day: 3), type: .work)
        wd3.note = "Réunion client"
        
        let wd4 = WorkDay(date: makeDate(year: 2024, month: 6, day: 4), type: .work)
        wd4.note = nil
        
        workDays = [wd1, wd2, wd3, wd4]
        
        let reunions = workDays.filter { $0.note?.lowercased().contains("réunion") ?? false }
        
        #expect(reunions.count == 2, "2 entrées contenant 'réunion'")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS DE STATISTIQUES MENSUELLES
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Tests de statistiques mensuelles")
struct MonthlyStatsTests {
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
    
    private func createWorkDay(date: Date, hours: Double, overtime: Int) -> WorkDay {
        let wd = WorkDay(date: date, type: .work)
        wd.totalHours = hours
        wd.overtimeSeconds = overtime
        return wd
    }
    
    @Test("Stats mois complet (20 jours ouvrés)")
    func statsMoisComplet() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Générer juin 2024 (20 jours ouvrés approximatifs)
        var workDayCount = 0
        for day in 1...30 {
            let date = makeDate(year: 2024, month: 6, day: day)
            let weekday = calendar.component(.weekday, from: date)
            
            if weekday != 1 && weekday != 7 {  // Pas weekend
                let hours = 8.0 + Double((day % 3) - 1) * 0.3
                let overtime = Int((hours - 8.2) * 3600)
                workDays.append(createWorkDay(date: date, hours: hours, overtime: overtime))
                workDayCount += 1
            }
        }
        
        let totalHours = workDays.reduce(0.0) { $0 + $1.totalHours }
        let avgHours = totalHours / Double(workDayCount)
        
        #expect(workDayCount >= 20, "Au moins 20 jours ouvrés en juin")
        #expect(avgHours > 7.5 && avgHours < 8.5, "Moyenne ~8h par jour")
    }
    
    @Test("Stats mois avec congés")
    func statsMoisAvecConges() {
        var workDays: [WorkDay] = []
        
        // 15 jours de travail
        for day in 1...15 {
            let wd = WorkDay(date: makeDate(year: 2024, month: 7, day: day), type: .work)
            wd.totalHours = 8.0
            workDays.append(wd)
        }
        
        // 5 jours de congé
        for day in 16...20 {
            workDays.append(WorkDay(date: makeDate(year: 2024, month: 7, day: day), type: .vacation))
        }
        
        let workOnly = workDays.filter { $0.type == .work }
        let vacationOnly = workDays.filter { $0.type == .vacation }
        let totalHours = workOnly.reduce(0.0) { $0 + $1.totalHours }
        
        #expect(workOnly.count == 15, "15 jours travaillés")
        #expect(vacationOnly.count == 5, "5 jours de congé")
        #expect(abs(totalHours - 120.0) < 0.01, "15 × 8 = 120h")
    }
    
    @Test("Stats mois avec overtime positif")
    func statsOvertimePositif() {
        var workDays: [WorkDay] = []
        
        // 20 jours avec 30min d'overtime chacun
        for day in 1...20 {
            let wd = createWorkDay(
                date: makeDate(year: 2024, month: 8, day: day),
                hours: 8.7,
                overtime: 1800  // 30 min
            )
            workDays.append(wd)
        }
        
        let totalOvertime = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        let overtimeHours = Double(totalOvertime) / 3600.0
        
        #expect(totalOvertime == 36000, "20 × 1800s = 36000s")
        #expect(abs(overtimeHours - 10.0) < 0.01, "10h d'overtime sur le mois")
    }
    
    @Test("Stats mois avec overtime négatif")
    func statsOvertimeNegatif() {
        var workDays: [WorkDay] = []
        
        // 20 jours avec -12min d'overtime chacun (8.0h au lieu de 8.2h)
        for day in 1...20 {
            let wd = createWorkDay(
                date: makeDate(year: 2024, month: 9, day: day),
                hours: 8.0,
                overtime: -720  // -12 min
            )
            workDays.append(wd)
        }
        
        let totalOvertime = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        let overtimeHours = Double(totalOvertime) / 3600.0
        
        #expect(totalOvertime == -14400, "20 × -720s = -14400s")
        #expect(abs(overtimeHours - (-4.0)) < 0.01, "-4h sur le mois")
    }
    
    @Test("Comparaison 2 mois")
    func comparaison2Mois() {
        var workDays: [WorkDay] = []
        let calendar = Calendar.current
        
        // Janvier: 22 jours × 8h
        for day in 1...22 {
            let wd = createWorkDay(
                date: makeDate(year: 2024, month: 1, day: day),
                hours: 8.0,
                overtime: -720
            )
            workDays.append(wd)
        }
        
        // Février: 18 jours × 9h
        for day in 1...18 {
            let wd = createWorkDay(
                date: makeDate(year: 2024, month: 2, day: day),
                hours: 9.0,
                overtime: 2880
            )
            workDays.append(wd)
        }
        
        let jan = workDays.filter { calendar.component(.month, from: $0.date) == 1 }
        let feb = workDays.filter { calendar.component(.month, from: $0.date) == 2 }
        
        let janHours = jan.reduce(0.0) { $0 + $1.totalHours }
        let febHours = feb.reduce(0.0) { $0 + $1.totalHours }
        
        let janOvertime = jan.reduce(0) { $0 + $1.overtimeSeconds }
        let febOvertime = feb.reduce(0) { $0 + $1.overtimeSeconds }
        
        #expect(abs(janHours - 176.0) < 0.01, "Janvier: 22 × 8 = 176h")
        #expect(abs(febHours - 162.0) < 0.01, "Février: 18 × 9 = 162h")
        #expect(janOvertime < 0, "Janvier: overtime négatif")
        #expect(febOvertime > 0, "Février: overtime positif")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS WorkDay.isValid + calculateHours() + shouldSync
// ══════════════════════════════════════════════════════════════════════════════

@Suite("WorkDay.isValid — validation métier")
struct WorkDayValidationTests {

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    // MARK: Cas valides

    @Test("Journée valide 8h-17h avec 1h pause")
    func valideJourneeNormale() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 8)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 15, hour: 17)
        wd.breakDuration = 3600
        wd.bonusAmount = 0
        #expect(wd.isValid)
    }

    @Test("Congé valide (pas d'heures requises)")
    func valideConge() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 7, day: 1), type: .vacation)
        #expect(wd.isValid)
    }

    @Test("Demi-journée valide")
    func valideDemiJournee() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .halfDayVacation)
        #expect(wd.isValid)
    }

    @Test("Maladie valide")
    func valideMaladie() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .sickLeave)
        #expect(wd.isValid)
    }

    @Test("Travail avec bonus positif")
    func valideBonus() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 8)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 15, hour: 17)
        wd.breakDuration = 3600
        wd.bonusAmount = 50.0
        #expect(wd.isValid)
    }

    // MARK: Cas invalides

    @Test("Invalide: fin avant début")
    func invalideFinAvantDebut() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 17)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 15, hour: 8)
        wd.breakDuration = 0
        #expect(!wd.isValid)
    }

    @Test("Invalide: durée > 24h")
    func invalideTropLong() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 0)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 16, hour: 1)  // 25h
        wd.breakDuration = 0
        #expect(!wd.isValid)
    }

    @Test("Invalide: pause > durée travaillée")
    func invalidePauseTropLongue() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 8)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 15, hour: 10)  // 2h
        wd.breakDuration = 10800  // 3h de pause > 2h travaillées
        #expect(!wd.isValid)
    }

    @Test("Invalide: bonus négatif")
    func invalideBonusNegatif() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 8)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 15, hour: 17)
        wd.breakDuration = 3600
        wd.bonusAmount = -10.0
        #expect(!wd.isValid)
    }

    @Test("Invalide: note > 500 caractères")
    func invalideTropLongueNote() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.startTime = makeDate(year: 2024, month: 6, day: 15, hour: 8)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 15, hour: 17)
        wd.breakDuration = 3600
        wd.note = String(repeating: "a", count: 501)
        #expect(!wd.isValid)
    }

    @Test("Invalide: date dans +11 ans")
    func invalideDateFutureLointaine() {
        let farFuture = Calendar.current.date(byAdding: .year, value: 11, to: Date())!
        let wd = WorkDay(date: farFuture, type: .vacation)
        #expect(!wd.isValid)
    }

    @Test("Invalide: date dans -11 ans")
    func invalideDatePasseLointaine() {
        let farPast = Calendar.current.date(byAdding: .year, value: -11, to: Date())!
        let wd = WorkDay(date: farPast, type: .vacation)
        #expect(!wd.isValid)
    }
}

@Suite("WorkDay.calculateHours() — calcul interne")
struct WorkDayCalculateHoursTests {

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    @Test("Journée 8h-17h 1h pause → 8h et overtime basé sur les réglages")
    func journeeNormale() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 17, hour: 0))  // Lundi
        wd.startTime = makeDate(year: 2024, month: 6, day: 17, hour: 8)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 17, hour: 17)
        wd.breakDuration = 3600

        wd.calculateHours()

        #expect(abs(wd.totalHours - 8.0) < 0.01)
    }

    @Test("Journée longue 7h-20h 1h pause → 12h")
    func journeeLongue() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 17, hour: 0))
        wd.startTime = makeDate(year: 2024, month: 6, day: 17, hour: 7)
        wd.endTime   = makeDate(year: 2024, month: 6, day: 17, hour: 20)
        wd.breakDuration = 3600

        wd.calculateHours()

        #expect(abs(wd.totalHours - 12.0) < 0.01)
    }

    @Test("Type congé → 0h, heures effacées")
    func typeCongeEfface() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 17, hour: 0), type: .vacation)
        wd.startTime = makeDate(year: 2024, month: 6, day: 17, hour: 8)  // sera vidé
        wd.endTime   = makeDate(year: 2024, month: 6, day: 17, hour: 17) // sera vidé

        wd.calculateHours()

        #expect(wd.totalHours == 0.0)
        #expect(wd.startTime == nil)
        #expect(wd.endTime == nil)
    }

    @Test("Pas de startTime → 0h (guard)")
    func sansDonnees() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 17, hour: 0), type: .work)
        // startTime et endTime nil par défaut

        wd.calculateHours()

        #expect(wd.totalHours == 0.0)
    }

    @Test("updateData recalcule et met à jour modifiedAt")
    func updateDataRecalcule() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 17, hour: 0), type: .work)
        let before = wd.modifiedAt

        // Petite pause pour avoir une différence de timestamp
        Thread.sleep(forTimeInterval: 0.01)

        wd.updateData(
            startTime: makeDate(year: 2024, month: 6, day: 17, hour: 8),
            endTime:   makeDate(year: 2024, month: 6, day: 17, hour: 17),
            breakDuration: 3600
        )

        #expect(wd.modifiedAt > before)
        #expect(abs(wd.totalHours - 8.0) < 0.01)
    }

    @Test("updateData: pause clampée si > durée travaillée")
    func updateDataClampPause() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 17, hour: 0), type: .work)
        wd.updateData(
            startTime: makeDate(year: 2024, month: 6, day: 17, hour: 8),
            endTime:   makeDate(year: 2024, month: 6, day: 17, hour: 10),  // 2h
            breakDuration: 7200  // 2h pause = durée max autorisée
        )
        // La pause est clampée à min(7200, 7200) = 7200, net = 0h
        #expect(wd.breakDuration <= 7200)
        #expect(wd.totalHours >= 0)
    }
}

@Suite("WorkDay.shouldSync — logique de synchronisation")
struct WorkDayShouldSyncTests {

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)!
    }

    @Test("shouldSync vrai à la création (nouvelle entrée à synchroniser)")
    func syncVraiACreation() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15))
        // needsSync = true dès la création → doit remonter
        #expect(wd.shouldSync)
    }

    @Test("shouldSync faux après markSynced()")
    func pasSyncApresMarkSynced() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15))
        #expect(wd.shouldSync)         // vrai avant sync
        wd.markSynced()
        #expect(!wd.shouldSync)        // faux après sync réussie
    }

    @Test("shouldSync vrai de nouveau après modification post-sync")
    func syncVraiApresModificationPostSync() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15), type: .work)
        wd.markSynced()                // simuler une sync réussie
        #expect(!wd.shouldSync)        // calme plat
        wd.updateData(                 // modification → déclenche needsSync = true
            startTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: wd.date),
            endTime:   Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: wd.date),
            breakDuration: 3600
        )
        #expect(wd.shouldSync)         // doit remonter à nouveau
    }

    @Test("shouldSync faux si isDeleted == true")
    func pasSyncSiSupprime() {
        let wd = WorkDay(date: makeDate(year: 2024, month: 6, day: 15))
        wd.isDeleted = true
        // needsSync est toujours true mais isDeleted bloque shouldSync
        #expect(!wd.shouldSync)
    }

    @Test("shouldSync: seules les entrées needsSync=true et non supprimées remontent")
    func filtreSyncCoherent() {
        var workDays: [WorkDay] = []

        // Déjà synchronisé → ne doit PAS remonter
        let wd1 = WorkDay(date: makeDate(year: 2024, month: 6, day: 10))
        wd1.markSynced()
        workDays.append(wd1)

        // Modifié après sync → doit remonter
        let wd2 = WorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .work)
        wd2.markSynced()
        wd2.updateData(
            startTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: wd2.date),
            endTime:   Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: wd2.date),
            breakDuration: 3600
        )
        workDays.append(wd2)

        // Supprimé → ne doit PAS remonter même si needsSync = true
        let wd3 = WorkDay(date: makeDate(year: 2024, month: 6, day: 12))
        wd3.isDeleted = true
        workDays.append(wd3)

        let toSync = workDays.filter { $0.shouldSync }
        #expect(toSync.count == 1, "Seul wd2 doit être synchronisé")
        #expect(toSync.first?.date == wd2.date)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS FORMATAGE HEURES/SECONDES (decimal vs HH:mm)
// All four formatter suites share UserSettings.shared.useDecimalHours.
// They are nested inside a single .serialized parent so no cross-suite races occur.
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Formatage heures et secondes (decimal vs HH:mm)", .serialized)
struct AllFormatterTests {

    // Sets useDecimalHours, runs body, then restores the original value.
    // Safe within .serialized suites because tests run one at a time.
    private func withDecimal(_ decimal: Bool, body: () -> Void) {
        let original = UserSettings.shared.useDecimalHours
        UserSettings.shared.useDecimalHours = decimal
        defer { UserSettings.shared.useDecimalHours = original }
        body()
    }

    // MARK: formattedHoursRounded

    @Test("formattedHoursRounded: 8.5h en mode HH:mm = 8h30")
    func hoursRounded_hhmm_8h30() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedHoursRounded(8.5) == "8h30")
        }
    }

    @Test("formattedHoursRounded: 8.5h en mode décimal = '8.50 h'")
    func hoursRounded_decimal_8h30() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedHoursRounded(8.5) == "8.50 h")
        }
    }

    @Test("formattedHoursRounded: 0h en mode HH:mm = 0h00")
    func hoursRounded_hhmm_zero() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedHoursRounded(0) == "0h00")
        }
    }

    @Test("formattedHoursRounded: 0h en mode décimal = '0.00 h'")
    func hoursRounded_decimal_zero() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedHoursRounded(0) == "0.00 h")
        }
    }

    @Test("formattedHoursRounded: -1.5h en mode HH:mm = -1h30")
    func hoursRounded_hhmm_negatif() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedHoursRounded(-1.5) == "-1h30")
        }
    }

    @Test("formattedHoursRounded: -1.5h en mode décimal = '-1.50 h'")
    func hoursRounded_decimal_negatif() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedHoursRounded(-1.5) == "-1.50 h")
        }
    }

    @Test("formattedHoursRounded: arrondi à la minute la plus proche")
    func hoursRounded_hhmm_arrondi() {
        // 1.008333h × 3600 = 3630s → round(3630/60) = 60.5 → 61 min → 1h01
        withDecimal(false) {
            let result = WorkTimeCalculations.formattedHoursRounded(1.008333)
            #expect(result == "1h00" || result == "1h01")
        }
    }

    // MARK: formattedSecondsRounded

    @Test("formattedSecondsRounded: 3600s en mode HH:mm = 1h00")
    func secondsRounded_hhmm_3600() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(3600) == "1h00")
        }
    }

    @Test("formattedSecondsRounded: 3600s en mode décimal = '1.00 h'")
    func secondsRounded_decimal_3600() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(3600) == "1.00 h")
        }
    }

    @Test("formattedSecondsRounded: 5400s en mode HH:mm = 1h30")
    func secondsRounded_hhmm_5400() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(5400) == "1h30")
        }
    }

    @Test("formattedSecondsRounded: 5400s en mode décimal = '1.50 h'")
    func secondsRounded_decimal_5400() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(5400) == "1.50 h")
        }
    }

    @Test("formattedSecondsRounded: 0s en mode HH:mm = 0h00")
    func secondsRounded_hhmm_zero() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(0) == "0h00")
        }
    }

    @Test("formattedSecondsRounded: -7200s en mode HH:mm = -2h00")
    func secondsRounded_hhmm_negatif() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(-7200) == "-2h00")
        }
    }

    @Test("formattedSecondsRounded: -7200s en mode décimal = '-2.00 h'")
    func secondsRounded_decimal_negatif() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedSecondsRounded(-7200) == "-2.00 h")
        }
    }

    // MARK: formattedHoursTruncated

    @Test("formattedHoursTruncated: 8.9h en HH:mm = 8h54 (troncature, pas arrondi vers 9h)")
    func hoursTruncated_hhmm_8h54() {
        withDecimal(false) {
            // 8.9 × 60 = 534 min → Int(534) = 534 → 8h54
            #expect(WorkTimeCalculations.formattedHoursTruncated(8.9) == "8h54")
        }
    }

    @Test("formattedHoursTruncated: 8.9h en décimal = '8.90 h'")
    func hoursTruncated_decimal_8h90() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedHoursTruncated(8.9) == "8.90 h")
        }
    }

    @Test("formattedHoursTruncated: 2.5h en HH:mm = 2h30")
    func hoursTruncated_hhmm_2h30() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedHoursTruncated(2.5) == "2h30")
        }
    }

    @Test("formattedHoursTruncated: 0h en HH:mm = 0h00")
    func hoursTruncated_hhmm_zero() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedHoursTruncated(0) == "0h00")
        }
    }

    @Test("formattedHoursTruncated: 40.25h en HH:mm = 40h15")
    func hoursTruncated_hhmm_40h15() {
        withDecimal(false) {
            // 40.25 × 60 = 2415 min → 40h15
            #expect(WorkTimeCalculations.formattedHoursTruncated(40.25) == "40h15")
        }
    }

    // MARK: formattedSecondsTruncated

    @Test("formattedSecondsTruncated: 3660s en HH:mm = 1h01 (secondes tronquées)")
    func secondsTruncated_hhmm_3660() {
        withDecimal(false) {
            // abs(3660) / 60 = 61 min (Int division) → 1h01
            #expect(WorkTimeCalculations.formattedSecondsTruncated(3660) == "1h01")
        }
    }

    @Test("formattedSecondsTruncated: 3660s en décimal = '1.02 h' ou '1.01 h'")
    func secondsTruncated_decimal_3660() {
        withDecimal(true) {
            // 3660/3600 = 1.0167 → "1.02 h"
            let result = WorkTimeCalculations.formattedSecondsTruncated(3660)
            #expect(result == "1.02 h" || result == "1.01 h")
        }
    }

    @Test("formattedSecondsTruncated: -5400s en HH:mm = -1h30")
    func secondsTruncated_hhmm_negatif() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedSecondsTruncated(-5400) == "-1h30")
        }
    }

    @Test("formattedSecondsTruncated: -5400s en décimal = '-1.50 h'")
    func secondsTruncated_decimal_negatif() {
        withDecimal(true) {
            #expect(WorkTimeCalculations.formattedSecondsTruncated(-5400) == "-1.50 h")
        }
    }

    @Test("formattedSecondsTruncated: 0s en HH:mm = 0h00")
    func secondsTruncated_hhmm_zero() {
        withDecimal(false) {
            #expect(WorkTimeCalculations.formattedSecondsTruncated(0) == "0h00")
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS VacationCalculations.remainingStats(for:workDays:annualEntitlement:)
// ══════════════════════════════════════════════════════════════════════════════

@Suite("VacationCalculations.remainingStats — avec WorkDay réels", .serialized)
struct RemainingStatsWithWorkDaysTests {

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    /// Configure UserSettings pour que l'année de début soit `startYear`
    /// avec `initialDays` de solde initial, puis exécute `body`, puis restore.
    private func withSettings(startYear: Int, initialDays: Double, body: () -> Void) {
        let settings = UserSettings.shared
        let originalStart = settings.vacationStartDate
        let originalInitial = settings.initialVacationDays
        settings.vacationStartDate = makeDate(year: startYear, month: 1, day: 1)
        settings.initialVacationDays = initialDays
        defer {
            settings.vacationStartDate = originalStart
            settings.initialVacationDays = originalInitial
        }
        body()
    }

    @Test("année de début: 10 jours initiaux, 3 utilisés → 7 restants, 0 droits ajoutés")
    func anneeDeDebut() {
        withSettings(startYear: 2024, initialDays: 10.0) {
            let workDays = [
                WorkDay(date: makeDate(year: 2024, month: 3, day: 4), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 3, day: 5), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 3, day: 6), type: .vacation),
            ]
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: workDays, annualEntitlement: 25.0
            )
            #expect(abs(stats.used - 3.0) < 0.01)
            #expect(abs(stats.carryIn - 10.0) < 0.01)
            #expect(abs(stats.remaining - 7.0) < 0.01)
        }
    }

    @Test("année suivante: 5 jours reportés + 25 droits - 8 utilisés = 22 restants")
    func anneeSuivante() {
        // startYear = 2023, 5 jours initiaux, 0 utilisés en 2023 → carry vers 2024 = 5
        withSettings(startYear: 2023, initialDays: 5.0) {
            let workDays2024 = [
                WorkDay(date: makeDate(year: 2024, month: 6, day: 1), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 2), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 3), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 4), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 5), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 6), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 7), type: .vacation),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 8), type: .vacation),
            ]
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: workDays2024, annualEntitlement: 25.0
            )
            // carry 2024 = max(0, 5 + 0 - 0) = 5; remaining = 5 + 25 - 8 = 22
            #expect(abs(stats.used - 8.0) < 0.01)
            #expect(abs(stats.carryIn - 5.0) < 0.01)
            #expect(abs(stats.remaining - 22.0) < 0.01)
        }
    }

    @Test("demi-journées comptent 0.5 dans remainingStats")
    func demiJourneesDansRemaining() {
        withSettings(startYear: 2024, initialDays: 10.0) {
            let workDays = [
                WorkDay(date: makeDate(year: 2024, month: 5, day: 1), type: .halfDayVacation),
                WorkDay(date: makeDate(year: 2024, month: 5, day: 2), type: .halfDayVacation),
            ]
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: workDays, annualEntitlement: 25.0
            )
            #expect(abs(stats.used - 1.0) < 0.01, "2 demi-journées = 1 jour utilisé")
            #expect(abs(stats.remaining - 9.0) < 0.01, "10 initiaux - 1 utilisé = 9 restants")
        }
    }

    @Test("entrées isDeleted ignorées dans remainingStats")
    func supprimesIgnores() {
        withSettings(startYear: 2024, initialDays: 10.0) {
            let activeVacation = WorkDay(date: makeDate(year: 2024, month: 4, day: 1), type: .vacation)
            let deletedVacation = WorkDay(date: makeDate(year: 2024, month: 4, day: 2), type: .vacation)
            deletedVacation.isDeleted = true
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: [activeVacation, deletedVacation], annualEntitlement: 25.0
            )
            #expect(abs(stats.used - 1.0) < 0.01, "Seul le congé actif compte")
            #expect(abs(stats.remaining - 9.0) < 0.01)
        }
    }

    @Test("aucun congé: used=0, remaining = carryIn (année de début)")
    func aucunCongeAnneeDebut() {
        withSettings(startYear: 2024, initialDays: 15.0) {
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: [], annualEntitlement: 25.0
            )
            #expect(abs(stats.used) < 0.01)
            #expect(abs(stats.remaining - 15.0) < 0.01)
            #expect(abs(stats.carryIn - 15.0) < 0.01)
        }
    }

    @Test("remaining plafonné à 0 quand plus de congés que de droits")
    func remainingNonNegatif() {
        // startYear 2023, initial 2, 0 utilisés → carry 2024 = 2
        // 2024: 2 carry + 25 droits = 27 disponibles; utilisés 30 → remaining = 0
        withSettings(startYear: 2023, initialDays: 2.0) {
            var workDays: [WorkDay] = []
            for day in 1...28 {
                // 28 jours complets + 4 demi-journées = 28 + 2 = 30 jours
                workDays.append(WorkDay(date: makeDate(year: 2024, month: 1, day: day), type: .vacation))
            }
            workDays.append(WorkDay(date: makeDate(year: 2024, month: 2, day: 1), type: .vacation))
            workDays.append(WorkDay(date: makeDate(year: 2024, month: 2, day: 2), type: .vacation))
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: workDays, annualEntitlement: 25.0
            )
            #expect(stats.remaining >= 0, "Le solde restant ne peut pas être négatif")
            #expect(stats.remaining == 0.0)
        }
    }

    @Test("types non-congé (work, sickLeave, holiday) n'affectent pas used")
    func autresTypesIgnores() {
        withSettings(startYear: 2024, initialDays: 10.0) {
            let workDays: [WorkDay] = [
                WorkDay(date: makeDate(year: 2024, month: 6, day: 10), type: .work),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 11), type: .sickLeave),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 12), type: .holiday),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 13), type: .compensatory),
                WorkDay(date: makeDate(year: 2024, month: 6, day: 14), type: .vacation),
            ]
            let stats = VacationCalculations.remainingStats(
                for: 2024, workDays: workDays, annualEntitlement: 25.0
            )
            #expect(abs(stats.used - 1.0) < 0.01, "Seul le .vacation compte")
            #expect(abs(stats.remaining - 9.0) < 0.01)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - TESTS StatsCache — hit/miss/invalidation
// ══════════════════════════════════════════════════════════════════════════════

@Suite("StatsCache — cache hit, miss et invalidation")
@MainActor
struct StatsCacheTests {

    // Vide le cache avant chaque test via invalidateAll()
    private func freshCache() -> StatsCache {
        let cache = StatsCache.shared
        cache.invalidateAll()
        return cache
    }

    @Test("cache miss retourne nil avant tout insert")
    func cacheMissAvantInsert() {
        let cache = freshCache()
        let result = cache.getYearlyStats(for: 2024)
        #expect(result == nil)
    }

    @Test("cache hit retourne les valeurs insérées immédiatement après")
    func cacheHitApresInsert() {
        let cache = freshCache()
        cache.cacheYearlyStats(
            year: 2024,
            workDays: 220,
            vacationDays: 15.0,
            sickDays: 3,
            totalHours: 1760.0,
            overtimeSeconds: 7200,
            totalBonus: 500.0
        )
        let result = cache.getYearlyStats(for: 2024)
        #expect(result != nil)
        #expect(result?.workDays == 220)
        #expect(result?.vacationDays == 15.0)
        #expect(result?.sickDays == 3)
        #expect(abs((result?.totalHours ?? 0) - 1760.0) < 0.01)
        #expect(result?.overtimeSeconds == 7200)
        #expect(abs((result?.totalBonus ?? 0) - 500.0) < 0.01)
        #expect(result?.year == 2024)
    }

    @Test("invalidateYear supprime l'entrée yearly du cache")
    func invalidateYearSupprime() {
        let cache = freshCache()
        cache.cacheYearlyStats(
            year: 2024, workDays: 200, vacationDays: 10, sickDays: 2,
            totalHours: 1600, overtimeSeconds: 0, totalBonus: 0
        )
        #expect(cache.getYearlyStats(for: 2024) != nil)
        cache.invalidateYear(2024)
        #expect(cache.getYearlyStats(for: 2024) == nil)
    }

    @Test("invalidateYear n'affecte pas les autres années")
    func invalidateYearIsole() {
        let cache = freshCache()
        cache.cacheYearlyStats(
            year: 2023, workDays: 210, vacationDays: 12, sickDays: 1,
            totalHours: 1680, overtimeSeconds: 3600, totalBonus: 0
        )
        cache.cacheYearlyStats(
            year: 2024, workDays: 200, vacationDays: 10, sickDays: 2,
            totalHours: 1600, overtimeSeconds: 0, totalBonus: 0
        )
        cache.invalidateYear(2024)
        #expect(cache.getYearlyStats(for: 2024) == nil, "2024 invalidé")
        #expect(cache.getYearlyStats(for: 2023) != nil, "2023 toujours en cache")
    }

    @Test("invalidateAll vide complètement le cache")
    func invalidateAllVide() {
        let cache = freshCache()
        cache.cacheYearlyStats(
            year: 2022, workDays: 215, vacationDays: 18, sickDays: 0,
            totalHours: 1720, overtimeSeconds: -1800, totalBonus: 0
        )
        cache.cacheYearlyStats(
            year: 2023, workDays: 210, vacationDays: 12, sickDays: 1,
            totalHours: 1680, overtimeSeconds: 3600, totalBonus: 0
        )
        cache.invalidateAll()
        #expect(cache.getYearlyStats(for: 2022) == nil)
        #expect(cache.getYearlyStats(for: 2023) == nil)
        #expect(cache.cacheInfo.yearly == 0)
    }

    @Test("cacheInfo reflète le nombre d'entrées actuelles")
    func cacheInfoCount() {
        let cache = freshCache()
        #expect(cache.cacheInfo.yearly == 0)
        cache.cacheYearlyStats(
            year: 2024, workDays: 200, vacationDays: 10, sickDays: 2,
            totalHours: 1600, overtimeSeconds: 0, totalBonus: 0
        )
        #expect(cache.cacheInfo.yearly == 1)
        cache.cacheYearlyStats(
            year: 2025, workDays: 205, vacationDays: 8, sickDays: 1,
            totalHours: 1640, overtimeSeconds: 1800, totalBonus: 0
        )
        #expect(cache.cacheInfo.yearly == 2)
    }

    @Test("second insert pour la même année écrase la valeur précédente")
    func ecrasementMemAnnee() {
        let cache = freshCache()
        cache.cacheYearlyStats(
            year: 2024, workDays: 100, vacationDays: 5, sickDays: 0,
            totalHours: 800, overtimeSeconds: 0, totalBonus: 0
        )
        cache.cacheYearlyStats(
            year: 2024, workDays: 220, vacationDays: 15, sickDays: 3,
            totalHours: 1760, overtimeSeconds: 7200, totalBonus: 500
        )
        let result = cache.getYearlyStats(for: 2024)
        #expect(result?.workDays == 220, "La deuxième valeur doit écraser la première")
        #expect(cache.cacheInfo.yearly == 1, "Toujours une seule entrée pour 2024")
    }
}
