import Foundation
import CloudKit

struct TimeRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    
    init(id: UUID = UUID(), date: Date, startTime: Date, endTime: Date) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
    }
    
    init?(record: CKRecord) {
        guard let date = record["date"] as? Date,
              let startTime = record["startTime"] as? Date,
              let endTime = record["endTime"] as? Date,
              let idString = record["id"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }
        
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "TimeRecord")
        record["id"] = id.uuidString
        record["date"] = date
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["duration"] = duration
        return record
    }
}

extension TimeRecord {
    var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: startTime)
    }
    
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: endTime)
    }
}