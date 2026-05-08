import Foundation
import os.log

/// Événements analytics de l'application
enum AnalyticsEvent: String {
    // MARK: - Navigation
    case screenView = "screen_view"
    case tabSelected = "tab_selected"
    
    // MARK: - Work Days
    case workDayCreated = "work_day_created"
    case workDayEdited = "work_day_edited"
    case workDayDeleted = "work_day_deleted"
    case workDayBatchDeleted = "work_day_batch_deleted"
    
    // MARK: - Calendar
    case calendarDateSelected = "calendar_date_selected"
    case calendarModeChanged = "calendar_mode_changed"
    
    // MARK: - Statistics
    case statsViewed = "stats_viewed"
    case statsYearChanged = "stats_year_changed"
    
    // MARK: - Vacations
    case vacationViewed = "vacation_viewed"
    case vacationYearChanged = "vacation_year_changed"
    
    // MARK: - Export
    case pdfExported = "pdf_exported"
    case csvExported = "csv_exported"
    
    // MARK: - Settings
    case settingsOpened = "settings_opened"
    case settingsChanged = "settings_changed"
    
    // MARK: - CloudKit
    case cloudKitSyncStarted = "cloudkit_sync_started"
    case cloudKitSyncCompleted = "cloudkit_sync_completed"
    case cloudKitSyncFailed = "cloudkit_sync_failed"
    
    // MARK: - Errors
    case errorOccurred = "error_occurred"
    
    // MARK: - Features
    case featureUsed = "feature_used"
}

/// Paramètres pour les événements analytics
struct AnalyticsParameters {
    var screenName: String?
    var tabName: String?
    var workDayType: String?
    var year: Int?
    var month: Int?
    var errorType: String?
    var featureName: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let screenName = screenName { dict["screen_name"] = screenName }
        if let tabName = tabName { dict["tab_name"] = tabName }
        if let workDayType = workDayType { dict["work_day_type"] = workDayType }
        if let year = year { dict["year"] = year }
        if let month = month { dict["month"] = month }
        if let errorType = errorType { dict["error_type"] = errorType }
        if let featureName = featureName { dict["feature_name"] = featureName }
        return dict
    }
}

/// Système d'analytics pour tracker l'usage de l'application
@MainActor
final class Analytics {
    static let shared = Analytics()
    
    private var isEnabled = true // Activé par défaut
    private var events: [(event: AnalyticsEvent, parameters: AnalyticsParameters, timestamp: Date)] = []
    private let maxEvents = 1000 // Limiter le buffer
    
    private init() {}
    
    /// Active ou désactive l'analytics (respecte la vie privée)
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        AppLogger.info("Analytics \(enabled ? "activé" : "désactivé")", category: AppLogger.general)
    }
    
    /// Enregistre un événement
    func log(_ event: AnalyticsEvent, parameters: AnalyticsParameters = AnalyticsParameters()) {
        guard isEnabled else { return }
        
        // Enregistrer localement (pour debug)
        events.append((event, parameters, Date()))
        if events.count > maxEvents {
            events.removeFirst()
        }
        
        // Firebase Analytics:
        // Analytics.logEvent(event.rawValue, parameters: parameters.toDictionary())
        
        // Pour un système custom:
        sendEvent(event, parameters: parameters)
        
        // Log pour debug
        #if DEBUG
        let paramsStr = parameters.toDictionary().isEmpty ? "" : " - \(parameters.toDictionary())"
        AppLogger.debug("Analytics: \(event.rawValue)\(paramsStr)", category: AppLogger.general)
        #endif
    }
    
    /// Envoie l'événement (peut être implémenté avec un backend custom)
    private func sendEvent(_ event: AnalyticsEvent, parameters: AnalyticsParameters) {
        // Ici, vous pouvez envoyer à votre backend analytics
        // Ou utiliser Firebase Analytics, Mixpanel, etc.
        
        // Pour l'instant, juste logger
        // En production, envoyer à un service d'analytics
    }
    
    /// Log un écran visualisé
    func logScreenView(_ screenName: String) {
        var params = AnalyticsParameters()
        params.screenName = screenName
        log(.screenView, parameters: params)
    }
    
    /// Log un onglet sélectionné
    func logTabSelected(_ tabName: String) {
        var params = AnalyticsParameters()
        params.tabName = tabName
        log(.tabSelected, parameters: params)
    }
    
    /// Log une erreur
    func logError(_ errorType: String, error: Error? = nil) {
        var params = AnalyticsParameters()
        params.errorType = errorType
        log(.errorOccurred, parameters: params)
        
        // Aussi envoyer au crash reporting
        if let error = error {
            CrashReporting.shared.recordError(error, userInfo: ["error_type": errorType])
        }
    }
    
    /// Log l'utilisation d'une feature
    func logFeatureUsed(_ featureName: String) {
        var params = AnalyticsParameters()
        params.featureName = featureName
        log(.featureUsed, parameters: params)
    }
    
    /// Exporte les événements (pour analyse)
    func exportEvents() -> [[String: Any]] {
        return events.map { event, parameters, timestamp in
            var dict: [String: Any] = [
                "event": event.rawValue,
                "timestamp": timestamp.timeIntervalSince1970
            ]
            dict.merge(parameters.toDictionary()) { (_, new) in new }
            return dict
        }
    }
}
