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
        static let dailyHoursByWeekday = "dailyHoursByWeekday"
        static let useCustomDailyHours = "useCustomDailyHours"
        static let annualVacationDays = "annualVacationDays"
        
        static let useDecimalHours = "useDecimalHours"
        static let hourlyRate = "hourlyRate"
        static let showLiveTimer = "showLiveTimer"
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

    /// Heures cibles par jour de la semaine (index 0 = lundi … 6 = dimanche).
    /// Source de vérité quand `useCustomDailyHours == true`. 0 = jour non travaillé.
    var dailyHoursByWeekday: [Double] {
        didSet {
            let normalized = Self.normalizedWeek(dailyHoursByWeekday)
            if normalized != dailyHoursByWeekday {
                dailyHoursByWeekday = normalized
                return
            }
            guard dailyHoursByWeekday != oldValue else { return }
            if let encoded = try? JSONEncoder().encode(dailyHoursByWeekday) {
                iCloudStore.set(encoded, forKey: Keys.dailyHoursByWeekday)
            }
            if useCustomDailyHours { syncDerivedFromDailyHours() }
        }
    }

    /// Active la saisie d'heures cibles différentes selon le jour de la semaine.
    var useCustomDailyHours: Bool {
        didSet {
            guard useCustomDailyHours != oldValue else { return }
            iCloudStore.set(useCustomDailyHours, forKey: Keys.useCustomDailyHours)
            if useCustomDailyHours {
                syncDerivedFromDailyHours()
            } else {
                updateDailyHours()
            }
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

    // MARK: - Rémunération
    /// Taux horaire brut. 0 = désactivé (aucun calcul de rémunération affiché).
    var hourlyRate: Double {
        didSet {
            iCloudStore.set(hourlyRate, forKey: Keys.hourlyRate)
        }
    }

    /// Affiche la carte chronomètre sur l'accueil. L'utilisateur peut la masquer
    /// s'il saisit uniquement ses heures à la main.
    var showLiveTimer: Bool {
        didSet {
            iCloudStore.set(showLiveTimer, forKey: Keys.showLiveTimer)
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
            return timeInterval == 0 ? defaultStartTime : Date(timeIntervalSince1970: timeInterval)
        }
        set {
            iCloudStore.set(newValue.timeIntervalSince1970, forKey: Keys.lastStartTimeInterval)
        }
    }
    
    var lastEndTime: Date {
        get {
            let timeInterval = iCloudStore.double(forKey: Keys.lastEndTimeInterval)
            return timeInterval == 0 ? defaultEndTime : Date(timeIntervalSince1970: timeInterval)
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
    private let defaultDailyHoursByWeekday: [Double] = [8.2, 8.2, 8.2, 8.2, 8.2, 0, 0]
    private let defaultVacationDays: Int = 25
    private let defaultVacationStartDate: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    private let defaultInitialVacationDays: Double = 0.0

    private var defaultStartTime: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var defaultEndTime: Date {
        Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    // MARK: - Initialisation privée (Singleton)
    private init() {
        self.weeklyHours         = defaultWeeklyHours
        self.workingDays         = defaultWorkingDays
        self.standardDailyHours  = defaultDailyHours
        self.dailyHoursByWeekday = defaultDailyHoursByWeekday
        self.useCustomDailyHours = false
        self.annualVacationDays  = defaultVacationDays
        self.vacationStartDate   = defaultVacationStartDate
        self.initialVacationDays = defaultInitialVacationDays
        self.useDecimalHours     = false
        self.hourlyRate          = 0.0
        self.showLiveTimer       = true
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

        if let data = iCloudStore.data(forKey: Keys.dailyHoursByWeekday),
           let decoded = try? JSONDecoder().decode([Double].self, from: data) {
            self.dailyHoursByWeekday = Self.normalizedWeek(decoded)
        }

        if iCloudStore.object(forKey: Keys.useCustomDailyHours) != nil {
            self.useCustomDailyHours = iCloudStore.bool(forKey: Keys.useCustomDailyHours)
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
        if iCloudStore.object(forKey: Keys.hourlyRate) != nil {
            self.hourlyRate = max(0, iCloudStore.double(forKey: Keys.hourlyRate))
        }
        if iCloudStore.object(forKey: Keys.showLiveTimer) != nil {
            self.showLiveTimer = iCloudStore.bool(forKey: Keys.showLiveTimer)
        }
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

        // En mode uniforme, refléter la valeur calculée sur chaque jour travaillé
        // pour que l'éditeur « par jour » démarre sur l'horaire réel de l'utilisateur.
        if !useCustomDailyHours {
            let mirrored = workingDays.map { $0 ? standardDailyHours : 0 }
            let normalized = Self.normalizedWeek(mirrored)
            if dailyHoursByWeekday != normalized {
                dailyHoursByWeekday = normalized
            }
        }
    }

    /// En mode « par jour », recale les valeurs dérivées (jours travaillés, total
    /// hebdomadaire et moyenne quotidienne) à partir des heures saisies par jour.
    private func syncDerivedFromDailyHours() {
        let week = Self.normalizedWeek(dailyHoursByWeekday)
        let newWorkingDays = week.map { $0 > 0 }
        if workingDays != newWorkingDays {
            workingDays = newWorkingDays
        }
        let total = week.reduce(0, +)
        if weeklyHours != total {
            weeklyHours = total
        } else {
            updateDailyHours()
        }
    }

    /// Garantit un tableau de 7 valeurs comprises entre 0 et 24 heures.
    static func normalizedWeek(_ values: [Double]) -> [Double] {
        var week = values.map { value -> Double in
            guard value.isFinite else { return 0 }
            return max(0, min(24, value))
        }
        if week.count < 7 {
            week.append(contentsOf: Array(repeating: 0, count: 7 - week.count))
        } else if week.count > 7 {
            week = Array(week.prefix(7))
        }
        return week
    }

    /// Index de jour de semaine façon app : 0 = lundi … 6 = dimanche. Pur, testable.
    static func weekdayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 6 : weekday - 2
    }

    /// Décision pure des heures attendues pour un index de jour donné.
    /// Extraite pour être testable sans l'état du singleton.
    static func expectedHours(
        weekdayIndex index: Int,
        useCustom: Bool,
        dailyHours: [Double],
        workingDays: [Bool],
        standardDailyHours: Double
    ) -> Double {
        guard index >= 0 && index < 7 else { return 0 }
        if useCustom {
            return normalizedWeek(dailyHours)[index]
        }
        guard index < workingDays.count else { return 0 }
        return workingDays[index] ? standardDailyHours : 0
    }

    /// Heures de travail attendues pour la date donnée, selon le mode actif.
    /// Comportement identique au précédent en mode uniforme.
    func expectedDailyHours(for date: Date, calendar: Calendar = .current) -> Double {
        Self.expectedHours(
            weekdayIndex: Self.weekdayIndex(for: date, calendar: calendar),
            useCustom: useCustomDailyHours,
            dailyHours: dailyHoursByWeekday,
            workingDays: workingDays,
            standardDailyHours: standardDailyHours
        )
    }
    
    // MARK: - Méthodes publiques
    func resetToDefaults() {
        weeklyHours = defaultWeeklyHours
        workingDays = defaultWorkingDays
        standardDailyHours = defaultDailyHours
        useCustomDailyHours = false
        dailyHoursByWeekday = defaultDailyHoursByWeekday
        annualVacationDays = defaultVacationDays
        vacationStartDate = defaultVacationStartDate
        initialVacationDays = defaultInitialVacationDays
        useDecimalHours = false
        hourlyRate = 0.0
        showLiveTimer = true
        hasCompletedOnboarding = false
        lastStartTime = defaultStartTime
        lastEndTime = defaultEndTime
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
    
    /// Indique si le calcul de rémunération est actif (taux horaire défini).
    var isHourlyRateEnabled: Bool { hourlyRate > 0 }

    /// Formate un montant dans la devise locale (séparée du taux horaire,
    /// réutilisable pour bonus, gains, etc.).
    func formatCurrency(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")
            .precision(.fractionLength(0...2)))
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
