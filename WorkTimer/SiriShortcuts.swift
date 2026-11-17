//
//  SiriShortcuts.swift
//  WorkTimer
//
//  Intégration des raccourcis Siri
//

import Foundation
import SwiftUI
import AppIntents

private enum SiriProAccess {
    @MainActor
    static func isAllowed() async -> Bool {
        await StoreManager.shared.refreshPurchaseStatus()
        return StoreManager.shared.isPro
    }

    static var requiredDialog: String {
        "siri.dialog.proRequired".localized
    }
}

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
            shortTitle: "siri.shortcut.arrival.title",
            systemImageName: "clock.badge.checkmark"
        )
        
        AppShortcut(
            intent: LogDepartureIntent(),
            phrases: [
                "Pointer mon départ avec \(.applicationName)",
                "Je finis le travail avec \(.applicationName)",
                "Terminer ma journée avec \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.departure.title",
            systemImageName: "clock.badge.xmark"
        )
        
        AppShortcut(
            intent: GetOvertimeIntent(),
            phrases: [
                "Mes heures supplémentaires avec \(.applicationName)",
                "Combien d'heures sup avec \(.applicationName)",
                "Mon solde d'heures avec \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.overtime.title",
            systemImageName: "clock.arrow.circlepath"
        )
        
        AppShortcut(
            intent: GetVacationBalanceIntent(),
            phrases: [
                "Mes jours de congés avec \(.applicationName)",
                "Combien de congés me reste avec \(.applicationName)",
                "Mon solde de vacances avec \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.vacation.title",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: GetWeeklySummaryIntent(),
            phrases: [
                "Mon résumé de la semaine avec \(.applicationName)",
                "Ma semaine de travail avec \(.applicationName)",
                "Récap de ma semaine avec \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.weeklySummary.title",
            systemImageName: "chart.bar.doc.horizontal"
        )

        AppShortcut(
            intent: QuickAddWorkDayIntent(),
            phrases: [
                "Ajouter une journée avec \(.applicationName)",
                "Créer une entrée avec \(.applicationName)",
                "Nouvelle journée avec \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.quickAdd.title",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: OpenWorkTimerDestinationIntent(),
            phrases: [
                "Ouvrir \(\.$destination) dans \(.applicationName)",
                "Afficher \(\.$destination) avec \(.applicationName)",
                "Aller à \(\.$destination) dans \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.openDestination.title",
            systemImageName: "arrow.forward.circle"
        )

        AppShortcut(
            intent: OpenCalendarDateIntent(),
            phrases: [
                "Ouvrir une date dans \(.applicationName)",
                "Afficher une journée avec \(.applicationName)",
                "Voir le calendrier à une date avec \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.openDate.title",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: OpenCalendarPresetIntent(),
            phrases: [
                "Ouvrir \(\.$preset) dans \(.applicationName)",
                "Afficher \(\.$preset) avec \(.applicationName)",
                "Voir \(\.$preset) dans \(.applicationName)"
            ],
            shortTitle: "siri.shortcut.openPresetDate.title",
            systemImageName: "calendar.circle"
        )
    }
}

// MARK: - Log Arrival Intent

struct LogArrivalIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.arrival.title"
    static var description = IntentDescription("intent.arrival.description")

    static var supportedModes: IntentModes { .foreground(.immediate) }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let now = Date()
        let timeString = now.formatted(.dateTime.hour().minute())

        // Démarre le chronomètre en direct (consommé par l'app au premier plan).
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "siri_timer_start_time")
        UserDefaults.standard.set(true, forKey: "siri_should_start_timer")

        return .result(dialog: "\("siri.dialog.arrival".localized(timeString))")
    }
}

// MARK: - Log Departure Intent

struct LogDepartureIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.departure.title"
    static var description = IntentDescription("intent.departure.description")

    static var supportedModes: IntentModes { .foreground(.immediate) }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let now = Date()
        let timeString = now.formatted(.dateTime.hour().minute())

        // Arrête le chronomètre en direct et enregistre la session (consommé par l'app).
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "siri_timer_stop_time")
        UserDefaults.standard.set(true, forKey: "siri_should_stop_timer")

        return .result(dialog: "\("siri.dialog.departure".localized(timeString))")
    }
}

// MARK: - Get Overtime Intent

struct GetOvertimeIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.overtime.title"
    static var description = IntentDescription("intent.overtime.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let overtimeSeconds = SiriSummaryProvider.currentSnapshot().overtimeSeconds
        
        let hours = abs(overtimeSeconds) / 3600
        let minutes = (abs(overtimeSeconds) % 3600) / 60
        let sign = overtimeSeconds >= 0 ? "+" : "-"
        let formatted = "\(sign)\(hours)h\(String(format: "%02d", minutes))"
        
        let message: String
        if overtimeSeconds > 0 {
            message = "siri.dialog.overtime.positive".localized(formatted)
        } else if overtimeSeconds < 0 {
            message = "siri.dialog.overtime.negative".localized(formatted)
        } else {
            message = "siri.dialog.overtime.zero".localized
        }
        
        return .result(dialog: "\(message)")
    }
}

// MARK: - Get Vacation Balance Intent

struct GetVacationBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.vacation.title"
    static var description = IntentDescription("intent.vacation.description")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let balance = SiriSummaryProvider.currentSnapshot().vacationBalance
        
        let formatted = balance.formatted(.number.precision(.fractionLength(1)))
        
        let message: String
        if balance > 10 {
            message = "siri.dialog.vacation.high".localized(formatted)
        } else if balance > 0 {
            message = "siri.dialog.vacation.available".localized(formatted)
        } else {
            message = "siri.dialog.vacation.none".localized
        }
        
        return .result(dialog: "\(message)")
    }
}

// MARK: - Weekly Summary Intent (iOS 26 Enhanced)

struct GetWeeklySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.weeklySummary.title"
    static var description = IntentDescription("intent.weeklySummary.description")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let snapshot = SiriSummaryProvider.currentSnapshot()
        let overtimeSeconds = snapshot.overtimeSeconds
        let vacationBalance = snapshot.vacationBalance
        let weeklyHours = snapshot.weeklyHours

        let hours = abs(overtimeSeconds) / 3600
        let minutes = (abs(overtimeSeconds) % 3600) / 60
        let sign = overtimeSeconds >= 0 ? "+" : "-"
        let overtimeFormatted = "\(sign)\(hours)h\(String(format: "%02d", minutes))"

        let weeklyFormatted = weeklyHours.formatted(.number.precision(.fractionLength(1)))
        let vacationFormatted = vacationBalance.formatted(.number.precision(.fractionLength(1)))
        let message = "siri.dialog.weeklySummary".localized(weeklyFormatted, overtimeFormatted, vacationFormatted)

        return .result(dialog: "\(message)")
    }
}

// MARK: - Quick Actions Intent

struct QuickAddWorkDayIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.quickAdd.title"
    static var description = IntentDescription("intent.quickAdd.description")

    static var parameterSummary: some ParameterSummary {
        Summary("siri.intent.quickAdd.summary \(\.$dayType)")
    }
    
    @Parameter(title: "siri.intent.quickAdd.dayType")
    var dayType: WorkDayTypeIntentValue?
    
    static var supportedModes: IntentModes { .foreground(.immediate) }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let type = dayType?.workDayType.rawValue ?? WorkDayType.work.rawValue
        UserDefaults.standard.set(type, forKey: "siri_quick_add_type")
        UserDefaults.standard.set(true, forKey: "siri_should_quick_add")
        
        return .result(dialog: "\("siri.dialog.quickAdd".localized)")
    }
}

// MARK: - Open Destination Intent

struct OpenWorkTimerDestinationIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.openDestination.title"
    static var description = IntentDescription("intent.openDestination.description")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("siri.intent.openDestination.summary \(\.$destination)")
    }

    @Parameter(title: "siri.intent.openDestination.destination", default: .calendar)
    var destination: WorkTimerDestinationIntentValue

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        UserDefaults.standard.set(destination.rawValue, forKey: "siri_open_destination")
        UserDefaults.standard.set(true, forKey: "siri_should_open_destination")

        return .result(dialog: "\("siri.dialog.openDestination".localized(destination.localizedName))")
    }
}

// MARK: - Open Calendar Date Intent

struct OpenCalendarDateIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.openDate.title"
    static var description = IntentDescription("intent.openDate.description")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("siri.intent.openDate.summary \(\.$date)")
    }

    @Parameter(title: "siri.intent.openDate.date", default: Date())
    var date: Date

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "siri_open_calendar_date")
        UserDefaults.standard.set(true, forKey: "siri_should_open_calendar_date")

        return .result(dialog: "\("siri.dialog.openDate".localized(date.formatted(date: .abbreviated, time: .omitted)))")
    }
}

// MARK: - Open Calendar Preset Intent

struct OpenCalendarPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "siri.intent.openPresetDate.title"
    static var description = IntentDescription("intent.openPresetDate.description")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("siri.intent.openPresetDate.summary \(\.$preset)")
    }

    @Parameter(title: "siri.intent.openPresetDate.preset", default: .today)
    var preset: CalendarDatePresetIntentValue

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard await SiriProAccess.isAllowed() else {
            return .result(dialog: "\(SiriProAccess.requiredDialog)")
        }

        let date = preset.date()
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "siri_open_calendar_date")
        UserDefaults.standard.set(true, forKey: "siri_should_open_calendar_date")

        return .result(dialog: "\("siri.dialog.openDatePreset".localized(preset.localizedName))")
    }
}

// MARK: - Work Day Type Enum

enum WorkDayTypeIntentValue: String, AppEnum {
    case work
    case vacation
    case halfDayVacation
    case sickLeave
    case holiday
    case compensatory

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "siri.intent.workDayType.title"

    static var caseDisplayRepresentations: [WorkDayTypeIntentValue: DisplayRepresentation] = [
        .work: "workDayType.work",
        .vacation: "workDayType.vacation",
        .halfDayVacation: "workDayType.halfDayVacation",
        .sickLeave: "workDayType.sickLeave",
        .holiday: "workDayType.holiday",
        .compensatory: "workDayType.compensatory"
    ]

    var workDayType: WorkDayType {
        switch self {
        case .work:
            return .work
        case .vacation:
            return .vacation
        case .halfDayVacation:
            return .halfDayVacation
        case .sickLeave:
            return .sickLeave
        case .holiday:
            return .holiday
        case .compensatory:
            return .compensatory
        }
    }
}

// MARK: - WorkTimer Destination Enum

enum WorkTimerDestinationIntentValue: String, AppEnum {
    case home
    case workDays
    case calendar
    case stats
    case settings

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "siri.intent.destination.title"

    static var caseDisplayRepresentations: [WorkTimerDestinationIntentValue: DisplayRepresentation] = [
        .home: "navigation.home",
        .workDays: "navigation.workDays",
        .calendar: "navigation.calendar",
        .stats: "navigation.stats",
        .settings: "navigation.settings"
    ]

    var localizedName: String {
        switch self {
        case .home:
            return "navigation.home".localized
        case .workDays:
            return "navigation.workDays".localized
        case .calendar:
            return "navigation.calendar".localized
        case .stats:
            return "navigation.stats".localized
        case .settings:
            return "navigation.settings".localized
        }
    }
}

// MARK: - Calendar Date Preset Enum

enum CalendarDatePresetIntentValue: String, AppEnum {
    case today
    case tomorrow
    case yesterday

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "siri.intent.datePreset.title"

    static var caseDisplayRepresentations: [CalendarDatePresetIntentValue: DisplayRepresentation] = [
        .today: "siri.intent.datePreset.today",
        .tomorrow: "siri.intent.datePreset.tomorrow",
        .yesterday: "siri.intent.datePreset.yesterday"
    ]

    var localizedName: String {
        switch self {
        case .today:
            return "siri.intent.datePreset.today".localized
        case .tomorrow:
            return "siri.intent.datePreset.tomorrow".localized
        case .yesterday:
            return "siri.intent.datePreset.yesterday".localized
        }
    }

    func date(relativeTo referenceDate: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Date {
        let startOfDay = calendar.startOfDay(for: referenceDate)

        switch self {
        case .today:
            return startOfDay
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        }
    }
}

// MARK: - Siri Helper

class SiriShortcutsHelper {
    static let shared = SiriShortcutsHelper()
    private static let appShortcutParametersRefreshKey = "siri_app_shortcuts_parameter_refresh_signature"
    private static let appShortcutParametersSchemaVersion = "2026-05-24.1"

    private init() {}

    @discardableResult
    func refreshAppShortcutParametersIfNeeded(
        signature: String = SiriShortcutsHelper.currentAppShortcutParametersSignature(),
        updateParameters: () -> Void = WorkTimerShortcuts.updateAppShortcutParameters
    ) -> Bool {
        guard UserDefaults.standard.string(forKey: Self.appShortcutParametersRefreshKey) != signature else {
            return false
        }

        updateParameters()
        UserDefaults.standard.set(signature, forKey: Self.appShortcutParametersRefreshKey)
        return true
    }
    
    /// Met à jour les données en cache pour Siri
    func updateCachedData(overtimeSeconds: Int, vacationBalance: Double, weeklyHours: Double = 0) {
        UserDefaults.standard.set(overtimeSeconds, forKey: "cached_overtime_seconds")
        UserDefaults.standard.set(vacationBalance, forKey: "cached_vacation_balance")
        UserDefaults.standard.set(weeklyHours, forKey: "cached_weekly_hours")
    }

    func updateCachedData(_ snapshot: SiriSummarySnapshot) {
        updateCachedData(
            overtimeSeconds: snapshot.overtimeSeconds,
            vacationBalance: snapshot.vacationBalance,
            weeklyHours: snapshot.weeklyHours
        )
    }

    func cachedSummarySnapshot() -> SiriSummarySnapshot {
        SiriSummarySnapshot(
            overtimeSeconds: UserDefaults.standard.integer(forKey: "cached_overtime_seconds"),
            vacationBalance: UserDefaults.standard.double(forKey: "cached_vacation_balance"),
            weeklyHours: UserDefaults.standard.double(forKey: "cached_weekly_hours")
        )
    }
    
    /// Vérifie si Siri a demandé de créer une entrée
    func checkSiriActions() -> SiriAction? {
        if UserDefaults.standard.bool(forKey: "siri_should_start_timer") {
            let startTime = UserDefaults.standard.double(forKey: "siri_timer_start_time")
            consumeActionFlag("siri_should_start_timer")
            return .startTimer(at: Date(timeIntervalSince1970: startTime))
        }

        if UserDefaults.standard.bool(forKey: "siri_should_stop_timer") {
            let stopTime = UserDefaults.standard.double(forKey: "siri_timer_stop_time")
            consumeActionFlag("siri_should_stop_timer")
            return .stopTimer(at: Date(timeIntervalSince1970: stopTime))
        }

        if UserDefaults.standard.bool(forKey: "siri_should_create_entry") {
            let arrivalTime = UserDefaults.standard.double(forKey: "siri_arrival_time")
            consumeActionFlag("siri_should_create_entry")
            return .createEntry(arrivalTime: Date(timeIntervalSince1970: arrivalTime))
        }
        
        if UserDefaults.standard.bool(forKey: "siri_should_update_entry") {
            let departureTime = UserDefaults.standard.double(forKey: "siri_departure_time")
            consumeActionFlag("siri_should_update_entry")
            return .updateEntry(departureTime: Date(timeIntervalSince1970: departureTime))
        }
        
        if UserDefaults.standard.bool(forKey: "siri_should_quick_add") {
            let type = UserDefaults.standard.string(forKey: "siri_quick_add_type") ?? WorkDayType.work.rawValue
            consumeActionFlag("siri_should_quick_add")
            return .quickAdd(type: WorkDayType(rawValue: type) ?? .work)
        }

        if UserDefaults.standard.bool(forKey: "siri_should_open_destination") {
            let rawDestination = UserDefaults.standard.string(forKey: "siri_open_destination") ?? WorkTimerDestinationIntentValue.calendar.rawValue
            consumeActionFlag("siri_should_open_destination")
            return .openDestination(WorkTimerDestinationIntentValue(rawValue: rawDestination) ?? .calendar)
        }

        if UserDefaults.standard.bool(forKey: "siri_should_open_calendar_date") {
            let timestamp = UserDefaults.standard.double(forKey: "siri_open_calendar_date")
            consumeActionFlag("siri_should_open_calendar_date")
            return .openCalendarDate(Date(timeIntervalSince1970: timestamp))
        }
        
        return nil
    }

    private func consumeActionFlag(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
    }

    private static func currentAppShortcutParametersSignature() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version).\(build).\(appShortcutParametersSchemaVersion)"
    }
    
    enum SiriAction {
        case startTimer(at: Date)
        case stopTimer(at: Date)
        case createEntry(arrivalTime: Date)
        case updateEntry(departureTime: Date)
        case quickAdd(type: WorkDayType)
        case openDestination(WorkTimerDestinationIntentValue)
        case openCalendarDate(Date)
    }
}

// MARK: - Siri Settings View

struct SiriSettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("settings.siri".localized, systemImage: "mic.fill")
                        .font(.headline)
                    
                    Text("siri.description".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("siri.section.timeTracking".localized) {
                shortcutRow(
                    phrase: "siri.phrase.arrival".localized,
                    description: "siri.description.arrival".localized,
                    icon: "clock.badge.checkmark",
                    color: .green
                )
                
                shortcutRow(
                    phrase: "siri.phrase.departure".localized,
                    description: "siri.description.departure".localized,
                    icon: "clock.badge.xmark",
                    color: .orange
                )
            }
            
            Section("siri.section.consult".localized) {
                shortcutRow(
                    phrase: "siri.phrase.overtime".localized,
                    description: "siri.description.overtime".localized,
                    icon: "clock.arrow.circlepath",
                    color: .blue
                )
                
                shortcutRow(
                    phrase: "siri.phrase.vacation".localized,
                    description: "siri.description.vacation".localized,
                    icon: "sun.max.fill",
                    color: .yellow
                )
            }

            Section("siri.section.add".localized) {
                shortcutRow(
                    phrase: "siri.phrase.quickAdd".localized,
                    description: "siri.description.quickAdd".localized,
                    icon: "calendar.badge.plus",
                    color: .purple
                )
            }

            Section("siri.section.navigate".localized) {
                shortcutRow(
                    phrase: "siri.phrase.openDestination".localized,
                    description: "siri.description.openDestination".localized,
                    icon: "arrow.forward.circle",
                    color: .indigo
                )

                shortcutRow(
                    phrase: "siri.phrase.openDate".localized,
                    description: "siri.description.openDate".localized,
                    icon: "calendar.badge.clock",
                    color: .blue
                )

                shortcutRow(
                    phrase: "siri.phrase.openPresetDate".localized,
                    description: "siri.description.openPresetDate".localized,
                    icon: "calendar.circle",
                    color: .teal
                )
            }
            
            Section {
                ShortcutsLink(action: {})
                    .shortcutsLinkStyle(.automatic)
                    .accessibilityLabel("siri.openShortcuts".localized)
            } footer: {
                Text("siri.automationHelp".localized)
            }
        }
        .navigationTitle("settings.siri".localized)
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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SiriSettingsView()
    }
}
