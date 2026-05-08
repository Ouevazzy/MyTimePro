//
//  SiriShortcuts.swift
//  WorkTimer
//
//  Intégration des raccourcis Siri
//

import Foundation
import SwiftUI
import AppIntents

// MARK: - App Shortcuts Provider

struct WorkTimerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogArrivalIntent(),
            phrases: [
                "Pointer mon arrivée avec \(.applicationName)",
                "Je commence le travail avec \(.applicationName)",
                "Démarrer ma journée avec \(.applicationName)"
            ],
            shortTitle: "Pointer l'arrivée",
            systemImageName: "clock.badge.checkmark"
        )
        
        AppShortcut(
            intent: LogDepartureIntent(),
            phrases: [
                "Pointer mon départ avec \(.applicationName)",
                "Je finis le travail avec \(.applicationName)",
                "Terminer ma journée avec \(.applicationName)"
            ],
            shortTitle: "Pointer le départ",
            systemImageName: "clock.badge.xmark"
        )
        
        AppShortcut(
            intent: GetOvertimeIntent(),
            phrases: [
                "Mes heures supplémentaires avec \(.applicationName)",
                "Combien d'heures sup avec \(.applicationName)",
                "Mon solde d'heures avec \(.applicationName)"
            ],
            shortTitle: "Heures supplémentaires",
            systemImageName: "clock.arrow.circlepath"
        )
        
        AppShortcut(
            intent: GetVacationBalanceIntent(),
            phrases: [
                "Mes jours de congés avec \(.applicationName)",
                "Combien de congés me reste avec \(.applicationName)",
                "Mon solde de vacances avec \(.applicationName)"
            ],
            shortTitle: "Solde congés",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: GetWeeklySummaryIntent(),
            phrases: [
                "Mon résumé de la semaine avec \(.applicationName)",
                "Ma semaine de travail avec \(.applicationName)",
                "Récap de ma semaine avec \(.applicationName)"
            ],
            shortTitle: "Résumé semaine",
            systemImageName: "chart.bar.doc.horizontal"
        )
    }
}

// MARK: - Log Arrival Intent

struct LogArrivalIntent: AppIntent {
    static var title: LocalizedStringResource = "Pointer l'arrivée"
    static var description = IntentDescription("Enregistre votre heure d'arrivée au travail")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: now)
        
        // Sauvegarder l'heure d'arrivée dans UserDefaults pour la récupérer dans l'app
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "siri_arrival_time")
        UserDefaults.standard.set(true, forKey: "siri_should_create_entry")
        
        return .result(dialog: "Arrivée enregistrée à \(timeString). Ouvrez WorkTimer pour compléter votre journée.")
    }
}

// MARK: - Log Departure Intent

struct LogDepartureIntent: AppIntent {
    static var title: LocalizedStringResource = "Pointer le départ"
    static var description = IntentDescription("Enregistre votre heure de départ du travail")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: now)
        
        // Sauvegarder l'heure de départ
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "siri_departure_time")
        UserDefaults.standard.set(true, forKey: "siri_should_update_entry")
        
        return .result(dialog: "Départ enregistré à \(timeString). Bonne soirée !")
    }
}

// MARK: - Get Overtime Intent

struct GetOvertimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Consulter les heures supplémentaires"
    static var description = IntentDescription("Affiche votre solde d'heures supplémentaires")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Récupérer le cumul depuis UserDefaults (mis à jour par l'app)
        let overtimeSeconds = UserDefaults.standard.integer(forKey: "cached_overtime_seconds")
        
        let hours = abs(overtimeSeconds) / 3600
        let minutes = (abs(overtimeSeconds) % 3600) / 60
        let sign = overtimeSeconds >= 0 ? "+" : "-"
        let formatted = "\(sign)\(hours)h\(String(format: "%02d", minutes))"
        
        let message: String
        if overtimeSeconds > 0 {
            message = "Vous avez \(formatted) d'heures supplémentaires. Bon travail !"
        } else if overtimeSeconds < 0 {
            message = "Vous avez \(formatted) d'heures à rattraper."
        } else {
            message = "Votre solde d'heures est à zéro. Parfait !"
        }
        
        return .result(dialog: "\(message)")
    }
}

// MARK: - Get Vacation Balance Intent

struct GetVacationBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Consulter le solde de congés"
    static var description = IntentDescription("Affiche votre solde de jours de congés")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Récupérer le solde depuis UserDefaults (mis à jour par l'app)
        let balance = UserDefaults.standard.double(forKey: "cached_vacation_balance")
        
        let formatted = String(format: "%.1f", balance)
        
        let message: String
        if balance > 10 {
            message = "Il vous reste \(formatted) jours de congés. Pensez à prendre des vacances !"
        } else if balance > 0 {
            message = "Il vous reste \(formatted) jours de congés."
        } else {
            message = "Vous n'avez plus de jours de congés disponibles."
        }
        
        return .result(dialog: "\(message)")
    }
}

// MARK: - Weekly Summary Intent (iOS 26 Enhanced)

struct GetWeeklySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Résumé de la semaine"
    static var description = IntentDescription("Affiche un résumé de votre semaine de travail")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let overtimeSeconds = UserDefaults.standard.integer(forKey: "cached_overtime_seconds")
        let vacationBalance = UserDefaults.standard.double(forKey: "cached_vacation_balance")
        let weeklyHours = UserDefaults.standard.double(forKey: "cached_weekly_hours")

        let hours = abs(overtimeSeconds) / 3600
        let minutes = (abs(overtimeSeconds) % 3600) / 60
        let sign = overtimeSeconds >= 0 ? "+" : "-"
        let overtimeFormatted = "\(sign)\(hours)h\(String(format: "%02d", minutes))"

        let message = """
        Cette semaine : \(String(format: "%.1f", weeklyHours))h travaillées. \
        Heures sup : \(overtimeFormatted). \
        Congés restants : \(String(format: "%.1f", vacationBalance)) jours.
        """

        return .result(dialog: "\(message)")
    }
}

// MARK: - Quick Actions Intent

struct QuickAddWorkDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter une journée"
    static var description = IntentDescription("Ajoute rapidement une journée de travail")
    
    @Parameter(title: "Type")
    var dayType: WorkDayTypeEntity?
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let type = dayType?.rawValue ?? "work"
        UserDefaults.standard.set(type, forKey: "siri_quick_add_type")
        UserDefaults.standard.set(true, forKey: "siri_should_quick_add")
        
        return .result(dialog: "Ouverture de WorkTimer pour ajouter une journée...")
    }
}

// MARK: - Work Day Type Entity

struct WorkDayTypeEntity: AppEntity {
    var id: String
    var rawValue: String
    var displayName: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Type de journée"
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
    
    static var defaultQuery = WorkDayTypeQuery()
}

struct WorkDayTypeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WorkDayTypeEntity] {
        allTypes.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [WorkDayTypeEntity] {
        allTypes
    }
    
    private var allTypes: [WorkDayTypeEntity] {
        [
            WorkDayTypeEntity(id: "work", rawValue: "work", displayName: "Travail"),
            WorkDayTypeEntity(id: "vacation", rawValue: "vacation", displayName: "Congé"),
            WorkDayTypeEntity(id: "halfDayVacation", rawValue: "halfDayVacation", displayName: "Demi-congé"),
            WorkDayTypeEntity(id: "sickLeave", rawValue: "sickLeave", displayName: "Maladie"),
            WorkDayTypeEntity(id: "holiday", rawValue: "holiday", displayName: "Jour férié"),
            WorkDayTypeEntity(id: "compensatory", rawValue: "compensatory", displayName: "Récupération")
        ]
    }
}

// MARK: - Siri Helper

class SiriShortcutsHelper {
    static let shared = SiriShortcutsHelper()
    private init() {}
    
    /// Met à jour les données en cache pour Siri
    func updateCachedData(overtimeSeconds: Int, vacationBalance: Double, weeklyHours: Double = 0) {
        UserDefaults.standard.set(overtimeSeconds, forKey: "cached_overtime_seconds")
        UserDefaults.standard.set(vacationBalance, forKey: "cached_vacation_balance")
        UserDefaults.standard.set(weeklyHours, forKey: "cached_weekly_hours")
    }
    
    /// Vérifie si Siri a demandé de créer une entrée
    func checkSiriActions() -> SiriAction? {
        if UserDefaults.standard.bool(forKey: "siri_should_create_entry") {
            UserDefaults.standard.removeObject(forKey: "siri_should_create_entry")
            let arrivalTime = UserDefaults.standard.double(forKey: "siri_arrival_time")
            return .createEntry(arrivalTime: Date(timeIntervalSince1970: arrivalTime))
        }
        
        if UserDefaults.standard.bool(forKey: "siri_should_update_entry") {
            UserDefaults.standard.removeObject(forKey: "siri_should_update_entry")
            let departureTime = UserDefaults.standard.double(forKey: "siri_departure_time")
            return .updateEntry(departureTime: Date(timeIntervalSince1970: departureTime))
        }
        
        if UserDefaults.standard.bool(forKey: "siri_should_quick_add") {
            UserDefaults.standard.removeObject(forKey: "siri_should_quick_add")
            let type = UserDefaults.standard.string(forKey: "siri_quick_add_type") ?? "work"
            return .quickAdd(type: WorkDayType(rawValue: type) ?? .work)
        }
        
        return nil
    }
    
    enum SiriAction {
        case createEntry(arrivalTime: Date)
        case updateEntry(departureTime: Date)
        case quickAdd(type: WorkDayType)
    }
}

// MARK: - Siri Settings View

struct SiriSettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Raccourcis Siri", systemImage: "mic.fill")
                        .font(.headline)
                    
                    Text("Utilisez ces phrases avec Siri pour interagir avec WorkTimer :")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("Pointer") {
                shortcutRow(
                    phrase: "\"Hey Siri, pointer mon arrivée avec WorkTimer\"",
                    description: "Enregistre votre heure d'arrivée",
                    icon: "clock.badge.checkmark",
                    color: .green
                )
                
                shortcutRow(
                    phrase: "\"Hey Siri, pointer mon départ avec WorkTimer\"",
                    description: "Enregistre votre heure de départ",
                    icon: "clock.badge.xmark",
                    color: .orange
                )
            }
            
            Section("Consulter") {
                shortcutRow(
                    phrase: "\"Hey Siri, mes heures supplémentaires avec WorkTimer\"",
                    description: "Affiche votre solde d'heures",
                    icon: "clock.arrow.circlepath",
                    color: .blue
                )
                
                shortcutRow(
                    phrase: "\"Hey Siri, mes jours de congés avec WorkTimer\"",
                    description: "Affiche votre solde de congés",
                    icon: "sun.max.fill",
                    color: .yellow
                )
            }
            
            Section {
                Link(destination: URL(string: "shortcuts://")!) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundStyle(.blue)
                        Text("Ouvrir l'app Raccourcis")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Vous pouvez créer des automatisations personnalisées dans l'app Raccourcis d'Apple.")
            }
        }
        .navigationTitle("Raccourcis Siri")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func shortcutRow(phrase: String, description: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(phrase)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SiriSettingsView()
    }
}










