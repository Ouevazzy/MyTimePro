import CloudKit

extension CKRecord {
    func decode<T: Decodable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: self.dictionaryWithValues(forKeys: self.allKeys()))
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension CKContainer {
    func fetchUserRecordID() async throws -> CKRecord.ID {
        return try await withCheckedThrowingContinuation { continuation in
            self.fetchUserRecordID { recordID, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let recordID = recordID {
                    continuation.resume(returning: recordID)
                }
            }
        }
    }
}
