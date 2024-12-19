import CloudKit

extension CloudKitManager {
    func saveTimeRecord(_ timeRecord: TimeRecord) async throws {
        let record = timeRecord.toCKRecord()
        try await privateDatabase.save(record)
    }
    
    func fetchTimeRecords(for month: Date? = nil) async throws -> [TimeRecord] {
        var predicate: NSPredicate
        
        if let month = month {
            let calendar = Calendar.current
            guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
                  let endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) else {
                throw CloudKitError.invalidDate
            }
            
            predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        
        let query = CKQuery(recordType: "TimeRecord", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let (results, _) = try await privateDatabase.records(matching: query)
        return results.compactMap { TimeRecord(record: $0.1) }
    }
    
    func deleteTimeRecord(withID id: UUID) async throws {
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: "TimeRecord", predicate: predicate)
        
        let (results, _) = try await privateDatabase.records(matching: query)
        for record in results {
            try await privateDatabase.deleteRecord(withID: record.0)
        }
    }
    
    func shouldRestoreData() async throws -> Bool {
        let settings = try await fetchSettings()
        let timeRecords = try await fetchTimeRecords()
        return settings == nil && timeRecords.isEmpty
    }
}

extension CloudKitManager {
    enum CloudKitError: LocalizedError {
        case invalidDate
        
        var errorDescription: String? {
            switch self {
            case .invalidDate:
                return "Date invalide"
            }
        }
    }
}