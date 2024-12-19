import CloudKit
import Foundation

actor CloudKitManager {
    static let shared = CloudKitManager()
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.jordan-payez.MyTimePro")
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
    }
    
    // MARK: - Account Status
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
    
    // MARK: - Save Operations
    func saveSettings(_ settings: Settings) async throws {
        let record = try settings.toCKRecord()
        try await privateDatabase.save(record)
    }
    
    // MARK: - Fetch Operations
    func fetchSettings() async throws -> Settings? {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Settings", predicate: predicate)
        let (results, _) = try await privateDatabase.records(matching: query)
        
        if let record = results.first?.1 {
            return Settings(record: record)
        }
        return nil
    }
    
    // MARK: - Delete Operations
    func deleteSettings() async throws {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Settings", predicate: predicate)
        let (results, _) = try await privateDatabase.records(matching: query)
        
        for record in results {
            try await privateDatabase.deleteRecord(withID: record.0)
        }
    }
    
    // MARK: - Backup Operations
    func backupData(data: Data, filename: String) async throws -> CKRecord {
        let asset = CKAsset(fileURL: createTemporaryFile(data: data, filename: filename))
        let record = CKRecord(recordType: "Backup")
        record["data"] = asset
        record["filename"] = filename
        record["timestamp"] = Date()
        
        return try await privateDatabase.save(record)
    }
    
    func restoreLatestBackup() async throws -> Data? {
        let predicate = NSPredicate(value: true)
        let sort = NSSortDescriptor(key: "timestamp", ascending: false)
        let query = CKQuery(recordType: "Backup", predicate: predicate)
        query.sortDescriptors = [sort]
        
        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 1)
        guard let record = results.first?.1,
              let asset = record["data"] as? CKAsset,
              let fileURL = asset.fileURL else {
            return nil
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    // MARK: - Subscription Operations
    func subscribeToChanges() async throws {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "Settings",
            predicate: predicate,
            subscriptionID: "settings-changes",
            options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
    }
    
    // MARK: - Helper Methods
    private func createTemporaryFile(data: Data, filename: String) -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Error Extension
extension CloudKitManager {
    enum CloudKitError: LocalizedError {
        case accountNotAvailable
        case dataNotFound
        case backupFailed
        case restoreFailed
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .accountNotAvailable:
                return "Compte iCloud non disponible"
            case .dataNotFound:
                return "Données non trouvées"
            case .backupFailed:
                return "La sauvegarde a échoué"
            case .restoreFailed:
                return "La restauration a échoué"
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }
}
