import Foundation
import os.log

/// Système de logging structuré pour l'application
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.worktimer"
    
    // Catégories de logs
    static let cloudKit = OSLog(subsystem: subsystem, category: "CloudKit")
    static let data = OSLog(subsystem: subsystem, category: "Data")
    static let ui = OSLog(subsystem: subsystem, category: "UI")
    static let network = OSLog(subsystem: subsystem, category: "Network")
    static let validation = OSLog(subsystem: subsystem, category: "Validation")
    static let general = OSLog(subsystem: subsystem, category: "General")
    
    // MARK: - Méthodes de logging
    
    /// Log d'information
    static func info(_ message: String, category: OSLog = general) {
        os_log("%{public}@", log: category, type: .info, message)
    }
    
    /// Log de debug (uniquement en DEBUG)
    static func debug(_ message: String, category: OSLog = general) {
        #if DEBUG
        os_log("%{public}@", log: category, type: .debug, message)
        #endif
    }
    
    /// Log d'avertissement
    static func warning(_ message: String, category: OSLog = general) {
        os_log("%{public}@", log: category, type: .default, message)
    }
    
    /// Log d'erreur
    static func error(_ message: String, category: OSLog = general, error: Error? = nil) {
        if let error = error {
            os_log("%{public}@ - Error: %{public}@", log: category, type: .error, message, error.localizedDescription)
        } else {
            os_log("%{public}@", log: category, type: .error, message)
        }
    }
    
    /// Log de faute critique
    static func fault(_ message: String, category: OSLog = general, error: Error? = nil) {
        if let error = error {
            os_log("%{public}@ - Error: %{public}@", log: category, type: .fault, message, error.localizedDescription)
        } else {
            os_log("%{public}@", log: category, type: .fault, message)
        }
    }
}
