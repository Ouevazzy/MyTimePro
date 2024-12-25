import SwiftUI
import Combine

@Observable
class UserSettings {
    
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
    }
    
    // MARK: - Paramètres de temps de travail
    var weeklyHours: Double {
        didSet {
            iCloudStore.set(weeklyHours, forKey: Keys.weeklyHours)
            iCloudStore.synchronize()
            updateDailyHours()
        }
    }
    
    var workingDays: [Bool] {
        didSet {
            if let encoded = try? JSONEncoder().encode(workingDays) {
                iCloudStore.set(encoded, forKey: Keys.workingDays)
                iCloudStore.synchronize()
            }
            updateDailyHours()
        }
    }
    
    /// Calculé en fonction de weeklyHours et workingDays, mais on le stocke
    var standardDailyHours: Double {
        didSet {
            iCloudStore.set(standardDailyHours, forKey: Keys.standardDailyHours)
            iCloudStore.synchronize()
        }
    }
    
    var annualVacationDays: Int {
        didSet {
            iCloudStore.set(annualVacationDays, forKey: Keys.annualVacationDays)
            iCloudStore.synchronize()
        }
    }
    
    // MARK: - Préférences d'affichage
    var useDecimalHours: Bool {
        didSet {
            iCloudStore.set(useDecimalHours, forKey: Keys.useDecimalHours)
            iCloudStore.synchronize()
        }
    }
    
    // MARK: - État de l'application
    private(set) var isFirstLaunch: Bool {
        didSet {
            // On inverse la valeur pour marquer qu’on a lancé au moins une fois
            iCloudStore.set(!isFirstLaunch, forKey: Keys.hasLaunchedBefore)
            iCloudStore.synchronize()
        }
    }
    
    var hasCompletedOnboarding: Bool {
        didSet {
            iCloudStore.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
            iCloudStore.synchronize()
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
            iCloudStore.synchronize()
        }
    }
    
    var lastEndTime: Date {
        get {
            let timeInterval = iCloudStore.double(forKey: Keys.lastEndTimeInterval)
            return timeInterval == 0 ? Date() : Date(timeIntervalSince1970: timeInterval)
        }
        set {
            iCloudStore.set(newValue.timeIntervalSince1970, forKey: Keys.lastEndTimeInterval)
            iCloudStore.synchronize()
        }
    }
    
    // MARK: - Constantes par défaut
    private let defaultWeeklyHours: Double = 41.0
    private let defaultWorkingDays: [Bool] = [true, true, true, true, true, false, false]
    private let defaultDailyHours: Double = 8.0
    private let defaultVacationDays: Int = 25
    
    // MARK: - Initialisation privée (Singleton)
    private init() {
        // Initialisation en mémoire
        self.weeklyHours         = defaultWeeklyHours
        self.workingDays         = defaultWorkingDays
        self.standardDailyHours  = defaultDailyHours
        self.annualVacationDays  = defaultVacationDays
        self.useDecimalHours     = false
        self.isFirstLaunch       = true
        self.hasCompletedOnboarding = false
        
        // Charger les valeurs sauvegardées d’iCloud
        loadFromiCloud()
        
        // Mettre à jour standardDailyHours en conséquence
        updateDailyHours()
        
        // Observer les changements iCloud depuis d’autres appareils
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChangeExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
        
        // Forcer une synchronisation initiale
        iCloudStore.synchronize()
    }
    
    // MARK: - Méthodes privées
    
    /// Charge les valeurs depuis iCloud store (si présentes).
    private func loadFromiCloud() {
        // weeklyHours
        if iCloudStore.object(forKey: Keys.weeklyHours) != nil {
            self.weeklyHours = iCloudStore.double(forKey: Keys.weeklyHours)
        }
        
        // workingDays (JSON)
        if let data = iCloudStore.data(forKey: Keys.workingDays),
           let decoded = try? JSONDecoder().decode([Bool].self, from: data) {
            self.workingDays = decoded
        }
        
        // standardDailyHours
        if iCloudStore.object(forKey: Keys.standardDailyHours) != nil {
            self.standardDailyHours = iCloudStore.double(forKey: Keys.standardDailyHours)
        }
        
        // annualVacationDays
        if iCloudStore.object(forKey: Keys.annualVacationDays) != nil {
            self.annualVacationDays = Int(iCloudStore.longLong(forKey: Keys.annualVacationDays))
        }
        
        // useDecimalHours
        self.useDecimalHours = iCloudStore.bool(forKey: Keys.useDecimalHours)
        
        // isFirstLaunch
        // On inverse la logique "hasLaunchedBefore"
        let hasLaunchedBefore = iCloudStore.bool(forKey: Keys.hasLaunchedBefore)
        self.isFirstLaunch = !hasLaunchedBefore
        
        // hasCompletedOnboarding
        self.hasCompletedOnboarding = iCloudStore.bool(forKey: Keys.hasCompletedOnboarding)
        
        // lastStartTime / lastEndTime => gérés par les getters
    }
    
    /// Méthode appelée automatiquement quand l’iCloud Store change (depuis un autre appareil).
    @objc private func iCloudStoreDidChangeExternally(_ notification: Notification) {
        // Recharger toutes les valeurs
        loadFromiCloud()
        // Mettre à jour dailyHours
        updateDailyHours()
    }
    
    /// Met à jour standardDailyHours en fonction de weeklyHours et des jours travaillés
    private func updateDailyHours() {
        let workingDaysCount = workingDays.filter { $0 }.count
        if workingDaysCount > 0 {
            standardDailyHours = weeklyHours / Double(workingDaysCount)
        } else {
            // si 0 jours travaillés => on peut fixer 0 ou laisser un default
            standardDailyHours = 0
        }
    }
    
    // MARK: - Méthodes publiques
    
    /// Remet toutes les valeurs par défaut
    func resetToDefaults() {
        weeklyHours         = defaultWeeklyHours
        workingDays         = defaultWorkingDays
        standardDailyHours  = defaultDailyHours
        annualVacationDays  = defaultVacationDays
        useDecimalHours     = false
        hasCompletedOnboarding = false
        lastStartTime       = Date()
        lastEndTime         = Date()
        
        // On force la synchro iCloud
        iCloudStore.synchronize()
        updateDailyHours()
    }
    
    func updateLastUsedTimes(start: Date?, end: Date?) {
        if let start {
            lastStartTime = start
        }
        if let end {
            lastEndTime = end
        }
    }
    
    /// Formatte un nombre d'heures en texte, selon useDecimalHours
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
