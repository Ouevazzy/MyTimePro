import SwiftUI

@Observable
final class UserSettings {
    
    // MARK: - Singleton
    static let shared = UserSettings()
    
    // MARK: - iCloud Store
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    
    // MARK: - Enum pour les clés
    private enum Keys {
        static let weeklyHours = "weeklyHours"
        static let workingDays = "workingDays"
        static let standardDailyHours = "standardDailyHours"
        static let annualVacationDays = "annualVacationDays"
        
        static let useDecimalHours = "useDecimalHours"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        
        static let lastStartTimeInterval = "lastStartTimeInterval"
        static let lastEndTimeInterval   = "lastEndTimeInterval"
        static let lastBreakDuration     = "lastBreakDuration"
        
        // Nouvelles clés pour la gestion des vacances
        static let vacationStartDate = "vacationStartDate"
        static let initialVacationDays = "initialVacationDays"
    }
    
    // MARK: - Paramètres de temps de travail
    var weeklyHours: Double {
        didSet {
            iCloudStore.set(weeklyHours, forKey: Keys.weeklyHours)
            updateDailyHours()
        }
    }
    
    var workingDays: [Bool] {
        didSet {
            guard workingDays != oldValue else { return }
            do {
                let encoded = try JSONEncoder().encode(workingDays)
                iCloudStore.set(encoded, forKey: Keys.workingDays)
            } catch {
                AppLogger.error("Failed to encode workingDays", category: AppLogger.general, error: error)
            }
            updateDailyHours()
        }
    }
    
    var standardDailyHours: Double {
        didSet {
            iCloudStore.set(standardDailyHours, forKey: Keys.standardDailyHours)
        }
    }
    
    var annualVacationDays: Int {
        didSet {
            iCloudStore.set(annualVacationDays, forKey: Keys.annualVacationDays)
        }
    }
    
    // MARK: - Paramètres de gestion des vacances
    var vacationStartDate: Date {
        didSet {
            iCloudStore.set(vacationStartDate.timeIntervalSince1970, forKey: Keys.vacationStartDate)
        }
    }
    
    var initialVacationDays: Double {
        didSet {
            iCloudStore.set(initialVacationDays, forKey: Keys.initialVacationDays)
        }
    }
    
    // MARK: - Préférences d'affichage
    var useDecimalHours: Bool {
        didSet {
            iCloudStore.set(useDecimalHours, forKey: Keys.useDecimalHours)
        }
    }
    
    // MARK: - État de l'application
    var hasCompletedOnboarding: Bool {
        didSet {
            iCloudStore.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }
    
    // MARK: - Dernières heures utilisées
    var lastStartTime: Date {
        get {
            let timeInterval = iCloudStore.double(forKey: Keys.lastStartTimeInterval)
            return timeInterval == 0 ? Date() : Date(timeIntervalSince1970: timeInterval)
        }
        set {
            iCloudStore.set(newValue.timeIntervalSince1970, forKey: Keys.lastStartTimeInterval)
        }
    }
    
    var lastEndTime: Date {
        get {
            let timeInterval = iCloudStore.double(forKey: Keys.lastEndTimeInterval)
            return timeInterval == 0 ? Date() : Date(timeIntervalSince1970: timeInterval)
        }
        set {
            iCloudStore.set(newValue.timeIntervalSince1970, forKey: Keys.lastEndTimeInterval)
        }
    }

    /// Dernière durée de pause utilisée (en secondes). Par défaut 3600 (1h).
    var lastBreakDuration: TimeInterval {
        get {
            let value = iCloudStore.double(forKey: Keys.lastBreakDuration)
            return value > 0 ? value : 3600
        }
        set {
            iCloudStore.set(newValue, forKey: Keys.lastBreakDuration)
        }
    }
    
    // MARK: - Constantes par défaut
    private let defaultWeeklyHours: Double = 41.0
    private let defaultWorkingDays: [Bool] = [true, true, true, true, true, false, false]
    private let defaultDailyHours: Double = 8.0
    private let defaultVacationDays: Int = 25
    private let defaultVacationStartDate: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    private let defaultInitialVacationDays: Double = 0.0
    
    // MARK: - Initialisation privée (Singleton)
    private init() {
        self.weeklyHours         = defaultWeeklyHours
        self.workingDays         = defaultWorkingDays
        self.standardDailyHours  = defaultDailyHours
        self.annualVacationDays  = defaultVacationDays
        self.vacationStartDate   = defaultVacationStartDate
        self.initialVacationDays = defaultInitialVacationDays
        self.useDecimalHours     = false
        self.hasCompletedOnboarding = false
        
        // Charger les valeurs sauvegardées d'iCloud
        loadFromiCloud()
        
        // Mettre à jour standardDailyHours en conséquence
        updateDailyHours()
        
        // Observer les changements iCloud depuis d'autres appareils
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChangeExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // iOS 26: synchronize() supprimé — le système gère la sync automatiquement
    }
    
    // MARK: - Méthodes privées
    private func loadFromiCloud() {
        if iCloudStore.object(forKey: Keys.weeklyHours) != nil {
            self.weeklyHours = iCloudStore.double(forKey: Keys.weeklyHours)
        }
        
        if let data = iCloudStore.data(forKey: Keys.workingDays),
           let decoded = try? JSONDecoder().decode([Bool].self, from: data) {
            self.workingDays = decoded
        }
        
        if iCloudStore.object(forKey: Keys.standardDailyHours) != nil {
            self.standardDailyHours = iCloudStore.double(forKey: Keys.standardDailyHours)
        }
        
        if iCloudStore.object(forKey: Keys.annualVacationDays) != nil {
            let raw = Int(iCloudStore.longLong(forKey: Keys.annualVacationDays))
            self.annualVacationDays = max(0, min(365, raw))
        }
        
        // Charger la date de début des vacances
        if iCloudStore.object(forKey: Keys.vacationStartDate) != nil {
            let timeInterval = iCloudStore.double(forKey: Keys.vacationStartDate)
            self.vacationStartDate = Date(timeIntervalSince1970: timeInterval)
        }
        
        // Charger les jours de vacances initiaux
        if iCloudStore.object(forKey: Keys.initialVacationDays) != nil {
            self.initialVacationDays = iCloudStore.double(forKey: Keys.initialVacationDays)
        }
        
        self.useDecimalHours = iCloudStore.bool(forKey: Keys.useDecimalHours)
        self.hasCompletedOnboarding = iCloudStore.bool(forKey: Keys.hasCompletedOnboarding)
    }
    
    @objc private func iCloudStoreDidChangeExternally(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.loadFromiCloud()
            self?.updateDailyHours()
        }
    }
    
    private func updateDailyHours() {
        let workingDaysCount = workingDays.filter { $0 }.count
        if workingDaysCount > 0 {
            standardDailyHours = weeklyHours / Double(workingDaysCount)
        } else {
            standardDailyHours = 0
        }
    }
    
    // MARK: - Méthodes publiques
    func resetToDefaults() {
        weeklyHours = defaultWeeklyHours
        workingDays = defaultWorkingDays
        standardDailyHours = defaultDailyHours
        annualVacationDays = defaultVacationDays
        vacationStartDate = defaultVacationStartDate
        initialVacationDays = defaultInitialVacationDays
        useDecimalHours = false
        hasCompletedOnboarding = false
        lastStartTime = Date()
        lastEndTime = Date()
        lastBreakDuration = 3600

        // iOS 26: synchronize() supprimé — le système gère la sync automatiquement
        updateDailyHours()
    }
    
    func updateLastUsedTimes(start: Date?, end: Date?, breakDuration: TimeInterval? = nil) {
        if let start {
            lastStartTime = start
        }
        if let end {
            lastEndTime = end
        }
        if let breakDuration {
            lastBreakDuration = breakDuration
        }
    }
    
    func formatHours(_ hours: Double) -> String {
        if useDecimalHours {
            return String(format: "%.2f", hours)
        } else {
            let totalMinutes = Int(hours * 60)
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            return String(format: "%dh%02d", h, m)
        }
    }
}
