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
    static let dayNames: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        // Calendar weekday symbols start from Sunday, rotate to start from Monday
        var symbols = formatter.standaloneWeekdaySymbols ?? ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols.map { $0.capitalized }
    }()
    static let shortDayNames: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        var symbols = formatter.shortStandaloneWeekdaySymbols ?? ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }()
    
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
                title: NSLocalizedString("notification.morning.title", value: "🌅 Bonne journée !", comment: "Morning reminder notification title"),
                body: NSLocalizedString("notification.morning.body", value: "N'oubliez pas de pointer votre arrivée", comment: "Morning reminder notification body"),
                time: morningReminderTime,
                selectedDays: selectedDays
            )
        }
        
        // Rappel du soir
        if eveningReminderEnabled {
            scheduleDailyReminder(
                identifier: NotificationID.eveningReminder,
                title: NSLocalizedString("notification.evening.title", value: "🌙 Fin de journée", comment: "Evening reminder notification title"),
                body: NSLocalizedString("notification.evening.body", value: "N'oubliez pas de pointer votre départ", comment: "Evening reminder notification body"),
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
        content.title = "🧪 Test de notification"
        content.body = "Les notifications WorkTimer fonctionnent correctement !"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
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
    @State private var notificationService = NotificationService.shared
    @State private var showingAuthorizationAlert = false
    @State private var reminderDays: [Bool] = NotificationService.shared.reminderDays
    @State private var showTestSentAlert = false
    
    // États locaux pour forcer le rafraîchissement
    @State private var morningEnabled = NotificationService.shared.morningReminderEnabled
    @State private var eveningEnabled = NotificationService.shared.eveningReminderEnabled
    @State private var morningTime = NotificationService.shared.morningReminderTime
    @State private var eveningTime = NotificationService.shared.eveningReminderTime
    
    var body: some View {
        List {
            // Section autorisation
            Section {
                HStack {
                    Image(systemName: notificationService.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                        .foregroundStyle(notificationService.isAuthorized ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(.headline)
                        Text(notificationService.isAuthorized ? "Autorisées" : "Non autorisées")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !notificationService.isAuthorized {
                        Button("Autoriser") {
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
                Text("Autorisation")
            }
            
            // Section jours de rappel
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Jours actifs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            DayToggleButton(
                                day: NotificationService.shortDayNames[index],
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
                Text("Jours de notification")
            } footer: {
                Text("Sélectionnez les jours où vous souhaitez recevoir des rappels")
            }
            
            // Section rappel matin
            Section {
                Toggle(isOn: $morningEnabled) {
                    Label("Rappel du matin", systemImage: "sunrise.fill")
                }
                .disabled(!notificationService.isAuthorized)
                .onChange(of: morningEnabled) { _, newValue in
                    notificationService.morningReminderEnabled = newValue
                }
                
                if morningEnabled {
                    DatePicker(
                        "Heure du rappel",
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
                Text("Rappel d'arrivée")
            } footer: {
                if morningEnabled {
                    let activeCount = reminderDays.filter { $0 }.count
                    Text("Rappel programmé pour \(activeCount) jour\(activeCount > 1 ? "s" : "") par semaine")
                }
            }
            .animation(DS.Animation.micro, value: morningEnabled)
            
            // Section rappel soir
            Section {
                Toggle(isOn: $eveningEnabled) {
                    Label("Rappel du soir", systemImage: "sunset.fill")
                }
                .disabled(!notificationService.isAuthorized)
                .onChange(of: eveningEnabled) { _, newValue in
                    notificationService.eveningReminderEnabled = newValue
                }
                
                if eveningEnabled {
                    DatePicker(
                        "Heure du rappel",
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
                Text("Rappel de départ")
            } footer: {
                if eveningEnabled {
                    let activeCount = reminderDays.filter { $0 }.count
                    Text("Rappel programmé pour \(activeCount) jour\(activeCount > 1 ? "s" : "") par semaine")
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
                        Label("Envoyer une notification test", systemImage: "paperplane.fill")
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!notificationService.isAuthorized)
            } footer: {
                Text("La notification apparaîtra dans 2 secondes. Vérifiez le centre de notifications si l'app est au premier plan.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications désactivées", isPresented: $showingAuthorizationAlert) {
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Veuillez autoriser les notifications dans les réglages de votre appareil.")
        }
        .alert("Notification envoyée", isPresented: $showTestSentAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Une notification test a été programmée. Elle apparaîtra dans 2 secondes.")
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
}

// MARK: - Day Toggle Button
struct DayToggleButton: View {
    let day: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
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
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

