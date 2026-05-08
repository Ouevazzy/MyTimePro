import Foundation
import os.log

/// Abstraction pour le crash reporting (supporte Firebase Crashlytics, Sentry, etc.)
@MainActor
final class CrashReporting {
    static let shared = CrashReporting()
    
    private var isEnabled = false
    
    private init() {}
    
    /// Active le crash reporting (à appeler au démarrage de l'app)
    func configure() {
        #if DEBUG
        // En DEBUG, on peut désactiver ou utiliser un service de test
        AppLogger.debug("Crash Reporting désactivé en mode DEBUG", category: AppLogger.general)
        return
        #else
        // En RELEASE, activer le crash reporting
        isEnabled = true
        setupCrashReporting()
        #endif
    }
    
    /// Configure le service de crash reporting
    private func setupCrashReporting() {
        // Note: Pour utiliser Firebase Crashlytics, ajouter:
        // 1. Firebase SDK dans Package.swift
        // 2. FirebaseCrashlytics.configure()
        //
        // Pour Sentry, ajouter:
        // 1. Sentry SDK
        // 2. SentrySDK.start { options in ... }
        
        AppLogger.info("Crash Reporting configuré", category: AppLogger.general)
    }
    
    /// Enregistre un message pour le crash reporting
    func log(_ message: String) {
        guard isEnabled else { return }
        
        // Firebase Crashlytics:
        // Crashlytics.crashlytics().log(message)
        
        // Sentry:
        // SentrySDK.addBreadcrumb(Breadcrumb(level: .info, message: message))
        
        AppLogger.info("Crash Log: \(message)", category: AppLogger.general)
    }
    
    /// Enregistre une erreur non-fatale
    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        // Firebase Crashlytics:
        // let crashlytics = Crashlytics.crashlytics()
        // crashlytics.record(error: error)
        // if let userInfo = userInfo {
        //     for (key, value) in userInfo {
        //         crashlytics.setCustomValue(value, forKey: key)
        //     }
        // }
        
        // Sentry:
        // SentrySDK.capture(error: error) { scope in
        //     if let userInfo = userInfo {
        //         for (key, value) in userInfo {
        //             scope.setContext(value: value, key: key)
        //         }
        //     }
        // }
        
        AppLogger.error("Crash Reporting: Error recorded", category: AppLogger.general, error: error)
    }
    
    /// Définit une valeur personnalisée pour le crash reporting
    func setCustomValue(_ value: Any, forKey key: String) {
        guard isEnabled else { return }
        
        // Firebase Crashlytics:
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        
        // Sentry:
        // SentrySDK.configureScope { scope in
        //     scope.setContext(value: value, key: key)
        // }
        
        AppLogger.debug("Crash Reporting: Custom value set - \(key): \(value)", category: AppLogger.general)
    }
    
    /// Définit l'ID utilisateur pour le crash reporting
    func setUserID(_ userID: String) {
        guard isEnabled else { return }
        
        // Firebase Crashlytics:
        // Crashlytics.crashlytics().setUserID(userID)
        
        // Sentry:
        // SentrySDK.setUser(User(userId: userID))
        
        AppLogger.debug("Crash Reporting: User ID set - \(userID)", category: AppLogger.general)
    }
    
    /// Force un crash de test (uniquement en DEBUG)
    func testCrash() {
        #if DEBUG
        fatalError("Test crash - à supprimer en production")
        #endif
    }
}
