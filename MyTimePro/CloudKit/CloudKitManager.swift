import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    private let container: CKContainer
    private let database: CKDatabase
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.jordan-payez.MyTimePro")
        self.database = container.privateCloudDatabase
    }
    
    func saveSettings(_ settings: Settings) async throws {
        let record = CKRecord(recordType: "Settings")
        record.setValuesForKeys(settings.toDictionary())
        
        try await database.save(record)
    }
    
    func fetchSettings() async throws -> Settings? {
        let query = CKQuery(recordType: "Settings", predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query)
        guard let record = result.matchResults.first?.1 else { return nil }
        
        return Settings(record: record)
    }
}