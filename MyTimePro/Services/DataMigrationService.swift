import Foundation
import CloudKit

class DataMigrationService {
    static let shared = DataMigrationService()
    
    private init() {}
    
    func performMigrationIfNeeded() async throws {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let lastMigrationVersion = UserDefaults.standard.string(forKey: "LastMigrationVersion") ?? "0.0"
        
        if lastMigrationVersion != currentVersion {
            try await migrateData(from: lastMigrationVersion, to: currentVersion)
            UserDefaults.standard.set(currentVersion, forKey: "LastMigrationVersion")
        }
    }
    
    private func migrateData(from oldVersion: String, to newVersion: String) async throws {
        // Backup existing data
        if let settings = try? await CloudKitManager.shared.fetchSettings() {
            // Perform backup
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(settings) {
                UserDefaults.standard.set(data, forKey: "SettingsBackup_\(oldVersion)")
            }
        }
        
        // Perform migrations based on version
        switch oldVersion {
        case "0.0":
            try await migrateFrom0_0()
        default:
            break
        }
    }
    
    private func migrateFrom0_0() async throws {
        // Migration from initial version
        let settings = Settings(
            weeklyHours: UserDefaults.standard.double(forKey: "weeklyHours"),
            dailyHours: UserDefaults.standard.double(forKey: "dailyHours"),
            vacationDays: UserDefaults.standard.double(forKey: "vacationDays"),
            workingDays: Set(UserDefaults.standard.array(forKey: "workingDays") as? [Int] ?? Array(1...5))
        )
        try await CloudKitManager.shared.saveSettings(settings)
    }
}
