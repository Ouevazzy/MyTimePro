import SwiftUI
import Combine

@Observable
class UserSettings {
    
    // MARK: - Singleton
    static let shared = UserSettings()

    // MARK: - Accent Color Enum
    enum AccentColor: String, CaseIterable, Identifiable {
        case defaultBlue, green, orange, purple

        var id: String { self.rawValue }

        var color: Color {
            switch self {
            case .defaultBlue:
                return Color.blue // Or your specific default blue
            case .green:
                return Color.green
            case .orange:
                return Color.orange
            case .purple:
                return Color.purple
            }
        }

        var localizedName: String {
            switch self {
            case .defaultBlue:
                return NSLocalizedString("Default Blue", comment: "Default blue accent color")
            case .green:
                return NSLocalizedString("Green", comment: "Green accent color")
            case .orange:
                return NSLocalizedString("Orange", comment: "Orange accent color")
            case .purple:
                return NSLocalizedString("Purple", comment: "Purple accent color")
            }
        }
    }
    
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
        
        // Nouvelle clé pour le timer
        static let showTimerInHome = "showTimerInHome"

        // Clé pour la couleur d'accentuation
        static let accentColorName = "accentColorName"
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
    
    // Nouveau paramètre pour afficher/masquer le timer
    var showTimerInHome: Bool {
        didSet {
            iCloudStore.set(showTimerInHome, forKey: Keys.showTimerInHome)
            iCloudStore.synchronize()
        }
    }

    // MARK: - Accent Color Setting
    var accentColorName: String {
        didSet {
            iCloudStore.set(accentColorName, forKey: Keys.accentColorName)
            iCloudStore.synchronize()
            // Potentially notify observers if needed in the future
        }
    }

    var currentAccentUIColor: UIColor {
        return UIColor(currentAccentColor)
    }

    var currentAccentColor: Color {
        if let colorEnum = AccentColor(rawValue: accentColorName) {
            return colorEnum.color
        } else {
            // Fallback to default if the name is invalid
            return AccentColor.defaultBlue.color
        }
    }
    
    // MARK: - État de l'application
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
        self.weeklyHours         = defaultWeeklyHours
        self.workingDays         = defaultWorkingDays
        self.standardDailyHours  = defaultDailyHours
        self.annualVacationDays  = defaultVacationDays
        self.useDecimalHours     = false
        self.hasCompletedOnboarding = false
        self.showTimerInHome     = true // Afficher par défaut
        self.accentColorName     = AccentColor.defaultBlue.rawValue // Default accent color
        
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
        
        // Forcer une synchronisation initiale
        iCloudStore.synchronize()
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
            self.annualVacationDays = Int(iCloudStore.longLong(forKey: Keys.annualVacationDays))
        }
        
        self.useDecimalHours = iCloudStore.bool(forKey: Keys.useDecimalHours)
        self.hasCompletedOnboarding = iCloudStore.bool(forKey: Keys.hasCompletedOnboarding)
        
        // Charger le paramètre showTimerInHome
        if iCloudStore.object(forKey: Keys.showTimerInHome) != nil {
            self.showTimerInHome = iCloudStore.bool(forKey: Keys.showTimerInHome)
        }

        if let storedAccentColorName = iCloudStore.string(forKey: Keys.accentColorName) {
            self.accentColorName = storedAccentColorName
        } else {
            // If nothing is stored, set to default (already done in init, but good for safety)
            self.accentColorName = AccentColor.defaultBlue.rawValue
        }
    }
    
    @objc private func iCloudStoreDidChangeExternally(_ notification: Notification) {
        loadFromiCloud()
        updateDailyHours()
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
        useDecimalHours = false
        hasCompletedOnboarding = false
        showTimerInHome = true
        lastStartTime = Date()
        lastEndTime = Date()
        accentColorName = AccentColor.defaultBlue.rawValue // Reset to default
        
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
