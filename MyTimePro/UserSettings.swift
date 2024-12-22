import SwiftUI

@Observable
class UserSettings {
    static let shared = UserSettings()
    private let defaults = UserDefaults.standard
    
    // MARK: - Paramètres de temps de travail
    var weeklyHours: Double {
        didSet {
            defaults.set(weeklyHours, forKey: "weeklyHours")
            updateDailyHours()
        }
    }
    
    var workingDays: [Bool] {
        didSet {
            if let encoded = try? JSONEncoder().encode(workingDays) {
                defaults.set(encoded, forKey: "workingDays")
            }
            updateDailyHours()
        }
    }
    
    var standardDailyHours: Double {
        didSet {
            defaults.set(standardDailyHours, forKey: "standardDailyHours")
        }
    }
    
    var annualVacationDays: Int {
        didSet {
            defaults.set(annualVacationDays, forKey: "annualVacationDays")
        }
    }
    
    // MARK: - Préférences d'affichage
    var useDecimalHours: Bool {
        didSet {
            defaults.set(useDecimalHours, forKey: "useDecimalHours")
        }
    }
    
    // MARK: - État de l'application
    private(set) var isFirstLaunch: Bool {
        didSet {
            defaults.set(!isFirstLaunch, forKey: "hasLaunchedBefore")
        }
    }
    
    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    // MARK: - Dernières heures utilisées
    var lastStartTime: Date {
        get {
            let timeInterval = defaults.double(forKey: "lastStartTimeInterval")
            return timeInterval == 0 ? Date() : Date(timeIntervalSince1970: timeInterval)
        }
        set {
            defaults.set(newValue.timeIntervalSince1970, forKey: "lastStartTimeInterval")
        }
    }
    
    var lastEndTime: Date {
        get {
            let timeInterval = defaults.double(forKey: "lastEndTimeInterval")
            return timeInterval == 0 ? Date() : Date(timeIntervalSince1970: timeInterval)
        }
        set {
            defaults.set(newValue.timeIntervalSince1970, forKey: "lastEndTimeInterval")
        }
    }
    
    // MARK: - Constantes
    private let defaultWeeklyHours: Double = 40.0
    private let defaultWorkingDays: [Bool] = [true, true, true, true, true, false, false]
    private let defaultDailyHours: Double = 8.0
    private let defaultVacationDays: Int = 25
    
    // MARK: - Initialisation privée (Singleton)
    private init() {
        // Initialiser avec les valeurs par défaut
        self.weeklyHours = defaultWeeklyHours
        self.workingDays = defaultWorkingDays
        self.standardDailyHours = defaultDailyHours
        self.annualVacationDays = defaultVacationDays
        self.useDecimalHours = false
        self.isFirstLaunch = true
        self.hasCompletedOnboarding = false
        
        // Charger les valeurs sauvegardées
        loadSavedSettings()
        updateDailyHours()
    }
    
    // MARK: - Méthodes privées
    private func loadSavedSettings() {
        if let savedHours = defaults.object(forKey: "weeklyHours") as? Double {
            self.weeklyHours = savedHours
        }
        
        if let savedDaysData = defaults.data(forKey: "workingDays"),
           let savedDays = try? JSONDecoder().decode([Bool].self, from: savedDaysData) {
            self.workingDays = savedDays
        }
        
        if let savedDailyHours = defaults.object(forKey: "standardDailyHours") as? Double {
            self.standardDailyHours = savedDailyHours
        }
        
        if let savedVacationDays = defaults.object(forKey: "annualVacationDays") as? Int {
            self.annualVacationDays = savedVacationDays
        }
        
        self.useDecimalHours = defaults.bool(forKey: "useDecimalHours")
        self.isFirstLaunch = !defaults.bool(forKey: "hasLaunchedBefore")
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }
    
    private func updateDailyHours() {
        let workingDaysCount = workingDays.filter { $0 }.count
        if workingDaysCount > 0 {
            standardDailyHours = weeklyHours / Double(workingDaysCount)
        }
    }
    
    // MARK: - Méthodes publiques
    func resetToDefaults() {
        weeklyHours = defaultWeeklyHours
        workingDays = defaultWorkingDays
        standardDailyHours = defaultDailyHours
        annualVacationDays = defaultVacationDays
        useDecimalHours = false
        hasCompletedOnboarding = false
        lastStartTime = Date()
        lastEndTime = Date()
        updateDailyHours()
    }
    
    func updateLastUsedTimes(start: Date?, end: Date?) {
        if let start = start {
            lastStartTime = start
        }
        if let end = end {
            lastEndTime = end
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
