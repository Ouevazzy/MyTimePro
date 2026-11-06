//
//  NotificationService.swift
//  WorkTimer
//
//  Service de gestion des notifications de rappel
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
@Observable
class NotificationService {
    // MARK: - Singleton
    static let shared = NotificationService()
    
    // MARK: - Properties
    private(set) var isAuthorized = false
    private(set) var pendingNotifications: [UNNotificationRequest] = []
    private static let testNotificationDelay: TimeInterval = 5
    
    // MARK: - User Defaults Keys
    private enum Keys {
        static let morningReminderEnabled = "morningReminderEnabled"
        static let eveningReminderEnabled = "eveningReminderEnabled"
        static let morningReminderTime = "morningReminderTime"
        static let eveningReminderTime = "eveningReminderTime"
        static let reminderDays = "reminderDays" // Jours sélectionnés pour les rappels
    }
    
    // MARK: - Settings
    var morningReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.morningReminderEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.morningReminderEnabled)
            scheduleNotifications()
        }
    }
    
    var eveningReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.eveningReminderEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.eveningReminderEnabled)
            scheduleNotifications()
        }
    }
    
    var morningReminderTime: Date {
        get {
            if let interval = UserDefaults.standard.object(forKey: Keys.morningReminderTime) as? Double {
                return Date(timeIntervalSince1970: interval)
            }
            // Défaut: 8h00
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Keys.morningReminderTime)
            scheduleNotifications()
        }
    }
    
    var eveningReminderTime: Date {
        get {
            if let interval = UserDefaults.standard.object(forKey: Keys.eveningReminderTime) as? Double {
                return Date(timeIntervalSince1970: interval)
            }
            // Défaut: 17h30
            var components = DateComponents()
            components.hour = 17
            components.minute = 30
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Keys.eveningReminderTime)
            scheduleNotifications()
        }
    }
    
    /// Jours où les rappels sont actifs (Lundi à Dimanche)
    var reminderDays: [Bool] {
        get {
            if let data = UserDefaults.standard.data(forKey: Keys.reminderDays),
               let days = try? JSONDecoder().decode([Bool].self, from: data) {
                return days
            }
            // Par défaut : Lundi à Vendredi activés
            return [true, true, true, true, true, false, false]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Keys.reminderDays)
            }
            scheduleNotifications()
        }
    }
    
    // Noms des jours pour l'affichage - locale-aware
    static var dayNames: [String] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        // Calendar weekday symbols start from Sunday, rotate to start from Monday
        var symbols = formatter.standaloneWeekdaySymbols ?? ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols.map { $0.capitalized }
    }
    static var shortDayNames: [String] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        var symbols = formatter.shortStandaloneWeekdaySymbols ?? ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }
    
    // MARK: - Notification Identifiers
    private enum NotificationID {
        static let morningReminder = "com.worktimer.morning-reminder"
        static let eveningReminder = "com.worktimer.evening-reminder"
    }
    
    // MARK: - Initialization
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                scheduleNotifications()
            }
            
            return granted
        } catch {
            AppLogger.error("Notification authorization request failed", category: AppLogger.general, error: error)
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Scheduling
    func scheduleNotifications() {
        // Annuler toutes les notifications existantes pour les rappels
        var idsToRemove: [String] = []
        for i in 0..<7 {
            idsToRemove.append("\(NotificationID.morningReminder)-\(i)")
            idsToRemove.append("\(NotificationID.eveningReminder)-\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        
        guard isAuthorized else { return }
        
        let selectedDays = reminderDays
        
        // Rappel du matin
        if morningReminderEnabled {
            scheduleDailyReminder(
                identifier: NotificationID.morningReminder,
                title: "notification.morning.title".localized,
                body: "notification.morning.body".localized,
                time: morningReminderTime,
                selectedDays: selectedDays
            )
        }
        
        // Rappel du soir
        if eveningReminderEnabled {
            scheduleDailyReminder(
                identifier: NotificationID.eveningReminder,
                title: "notification.evening.title".localized,
                body: "notification.evening.body".localized,
                time: eveningReminderTime,
                selectedDays: selectedDays
            )
        }
        
        // Mettre à jour la liste des notifications en attente
        refreshPendingNotifications()
    }
    
    private func scheduleDailyReminder(
        identifier: String,
        title: String,
        body: String,
        time: Date,
        selectedDays: [Bool]
    ) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Mapper les jours (lundi=0 -> dimanche=6)
        // vers les weekdays du Calendar (dimanche=1, lundi=2, ..., samedi=7)
        let weekdayMapping = [2, 3, 4, 5, 6, 7, 1] // lun, mar, mer, jeu, ven, sam, dim
        
        for (index, isEnabled) in selectedDays.enumerated() {
            guard isEnabled else { continue }
            
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekdayMapping[index]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.badge = 1
            
            let request = UNNotificationRequest(
                identifier: "\(identifier)-\(index)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    AppLogger.error("Erreur lors de la planification: \(error)", category: AppLogger.general)
                }
            }
        }
    }
    
    // MARK: - Management
    func refreshPendingNotifications() {
        Task {
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            self.pendingNotifications = requests
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingNotifications = []
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                AppLogger.error("Erreur lors de la suppression du badge: \(error)", category: AppLogger.general)
            }
        }
    }
    
    // MARK: - Test Notification
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "notification.test.title".localized
        content.body = "notification.test.body".localized
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.testNotificationDelay, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.error("Erreur test notification: \(error)", category: AppLogger.general)
            }
        }
    }
}

// MARK: - SwiftUI View for Notification Settings
struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var notificationService = NotificationService.shared
    @State private var showingAuthorizationAlert = false
    @State private var reminderDays: [Bool] = NotificationService.shared.reminderDays
    @State private var showTestSentAlert = false
    
    // États locaux pour forcer le rafraîchissement
    @State private var morningEnabled = NotificationService.shared.morningReminderEnabled
    @State private var eveningEnabled = NotificationService.shared.eveningReminderEnabled
    @State private var morningTime = NotificationService.shared.morningReminderTime
    @State private var eveningTime = NotificationService.shared.eveningReminderTime

    private var activeReminderDaysCount: Int {
        reminderDays.filter { $0 }.count
    }
    
    var body: some View {
        List {
            // Section autorisation
            Section {
                HStack {
                    Image(systemName: notificationService.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                        .foregroundStyle(notificationService.isAuthorized ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("notification.title".localized)
                            .font(.headline)
                        Text(notificationService.isAuthorized ? "notification.authorized".localized : "notification.unauthorized".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !notificationService.isAuthorized {
                        Button("notification.authorize".localized) {
                            Task {
                                let granted = await notificationService.requestAuthorization()
                                if !granted {
                                    showingAuthorizationAlert = true
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("notification.section.authorization".localized)
            }
            
            // Section jours de rappel
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("notification.section.activeDays".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            DayToggleButton(
                                day: NotificationService.shortDayNames[index],
                                accessibilityName: NotificationService.dayNames[index],
                                isSelected: reminderDays[index],
                                isEnabled: notificationService.isAuthorized
                            ) {
                                reminderDays[index].toggle()
                                notificationService.reminderDays = reminderDays
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("notification.section.notificationDays".localized)
            } footer: {
                Text("notification.section.selectDaysHelp".localized)
            }
            
            // Section rappel matin
            Section {
                Toggle(isOn: $morningEnabled) {
                    Label("notification.reminder.morning".localized, systemImage: "sunrise.fill")
                }
                .disabled(!notificationService.isAuthorized)
                .onChange(of: morningEnabled) { _, newValue in
                    notificationService.morningReminderEnabled = newValue
                }
                
                if morningEnabled {
                    DatePicker(
                        "notification.reminder.time".localized,
                        selection: $morningTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!notificationService.isAuthorized)
                    .onChange(of: morningTime) { _, newValue in
                        notificationService.morningReminderTime = newValue
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } header: {
                Text("notification.reminder.arrival".localized)
            } footer: {
                if morningEnabled {
                    Text(scheduleSummary)
                }
            }
            .animation(DS.Animation.micro, value: morningEnabled)
            
            // Section rappel soir
            Section {
                Toggle(isOn: $eveningEnabled) {
                    Label("notification.reminder.evening".localized, systemImage: "sunset.fill")
                }
                .disabled(!notificationService.isAuthorized)
                .onChange(of: eveningEnabled) { _, newValue in
                    notificationService.eveningReminderEnabled = newValue
                }
                
                if eveningEnabled {
                    DatePicker(
                        "notification.reminder.time".localized,
                        selection: $eveningTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!notificationService.isAuthorized)
                    .onChange(of: eveningTime) { _, newValue in
                        notificationService.eveningReminderTime = newValue
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } header: {
                Text("notification.reminder.departure".localized)
            } footer: {
                if eveningEnabled {
                    Text(scheduleSummary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: eveningEnabled)
            
            // Section test
            Section {
                Button {
                    notificationService.sendTestNotification()
                    Haptic.notification(.success)
                    showTestSentAlert = true
                } label: {
                    HStack {
                        Label("notification.test.send".localized, systemImage: "paperplane.fill")
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!notificationService.isAuthorized)
            } footer: {
                Text("notification.test.footer".localized)
            }
        }
        .navigationTitle("notification.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("notification.alert.disabled.title".localized, isPresented: $showingAuthorizationAlert) {
            Button("notification.alert.openSettings".localized) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("action.cancel".localized, role: .cancel) { }
        } message: {
            Text("notification.alert.disabled.message".localized)
        }
        .alert("notification.alert.sent.title".localized, isPresented: $showTestSentAlert) {
            Button("action.done".localized, role: .cancel) { }
        } message: {
            Text("notification.alert.sent.message".localized)
        }
        .onAppear {
            notificationService.checkAuthorizationStatus()
            reminderDays = notificationService.reminderDays
            morningEnabled = notificationService.morningReminderEnabled
            eveningEnabled = notificationService.eveningReminderEnabled
            morningTime = notificationService.morningReminderTime
            eveningTime = notificationService.eveningReminderTime
        }
    }

    private var scheduleSummary: String {
        "notification.reminder.scheduleSummary".localized(
            activeReminderDaysCount,
            activeReminderDaysCount == 1 ? "time.day".localized : "time.days".localized
        )
    }
}

// MARK: - Day Toggle Button
struct DayToggleButton: View {
    let day: String
    let accessibilityName: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            Text(day)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : (isEnabled ? .primary : .secondary))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isSelected ? "notification.day.selected".localized : "notification.day.notSelected".localized)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
