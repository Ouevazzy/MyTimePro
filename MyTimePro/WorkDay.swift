import Foundation
import CloudKit
import SwiftUI

enum WorkDayType: String, Codable, CaseIterable {
    case work = "Travail"
    case vacation = "Congé"
    case halfDayVacation = "Demi-journée de congé"
    case sickLeave = "Maladie"
    case compensatory = "Journée compensatoire"
    case training = "Formation"
    case holiday = "Férié"
    
    var isWorkDay: Bool { self == .work }
    var isVacation: Bool { self == .vacation || self == .halfDayVacation }
    var isCompensatory: Bool { self == .compensatory }
    var isHalfDay: Bool { self == .halfDayVacation }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .vacation, .halfDayVacation: return "sun.max.fill"
        case .sickLeave: return "cross.fill"
        case .compensatory: return "arrow.2.squarepath"
        case .training: return "book.fill"
        case .holiday: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .work: return .blue
        case .vacation, .halfDayVacation: return .orange
        case .sickLeave: return .red
        case .compensatory: return .green
        case .training: return .purple
        case .holiday: return .yellow
        }
    }
}

class WorkDay: Identifiable, ObservableObject {
    let id: UUID
    var cloudKitRecordID: CKRecord.ID?
    
    @Published var date: Date
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var breakDuration: TimeInterval
    @Published var totalHours: Double
    @Published var overtimeSeconds: Int
    @Published var typeRawValue: String
    @Published var note: String?
    @Published var bonusAmount: Double
    
    var type: WorkDayType {
        get { WorkDayType(rawValue: typeRawValue) ?? .work }
        set {
            typeRawValue = newValue.rawValue
            calculateHours()
        }
    }
    
    init(date: Date = Date(), type: WorkDayType = .work) {
        self.id = UUID()
        self.date = date
        self.typeRawValue = type.rawValue
        self.startTime = UserSettings.shared.lastStartTime
        self.endTime = UserSettings.shared.lastEndTime
        self.breakDuration = 3600
        self.totalHours = 0.0
        self.overtimeSeconds = 0
        self.note = ""
        self.bonusAmount = 0.0
        calculateHours()
    }
    
    convenience init?(record: CKRecord) {
        guard let dateTimestamp = record["date"] as? Date else {
            return nil
        }
        
        self.init(date: dateTimestamp)
        
        self.cloudKitRecordID = record.recordID
        if let typeString = record["type"] as? String {
            self.typeRawValue = typeString
        }
        self.startTime = record["startTime"] as? Date
        self.endTime = record["endTime"] as? Date
        self.breakDuration = record["breakDuration"] as? TimeInterval ?? 3600
        self.totalHours = record["totalHours"] as? Double ?? 0.0
        self.overtimeSeconds = record["overtimeSeconds"] as? Int ?? 0
        self.note = record["note"] as? String
        self.bonusAmount = record["bonusAmount"] as? Double ?? 0.0
        
        calculateHours()
    }
    
    func toRecord() -> CKRecord {
        let recordID = cloudKitRecordID ?? CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "WorkDay", recordID: recordID)
        
        record["date"] = date as CKRecordValue
        record["type"] = typeRawValue as CKRecordValue
        record["startTime"] = startTime as CKRecordValue?
        record["endTime"] = endTime as CKRecordValue?
        record["breakDuration"] = breakDuration as CKRecordValue
        record["totalHours"] = totalHours as CKRecordValue
        record["overtimeSeconds"] = overtimeSeconds as CKRecordValue
        record["note"] = note as CKRecordValue?
        record["bonusAmount"] = bonusAmount as CKRecordValue
        
        return record
    }
    
    func calculateHours() {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        
        var standardSeconds = 0
        
        if type == .work || type == .compensatory {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
            
            if adjustedWeekday >= 0 && adjustedWeekday < settings.workingDays.count && settings.workingDays[adjustedWeekday] {
                standardSeconds = Int(round(settings.standardDailyHours * 3600))
            }
        }
        
        totalHours = 0
        overtimeSeconds = 0
        
        switch type {
        case .work:
            guard let start = startTime, let end = endTime else { return }
            let workedSeconds = end.timeIntervalSince(start) - breakDuration
            totalHours = workedSeconds / 3600.0
            overtimeSeconds = Int(round(workedSeconds)) - standardSeconds
            
        case .vacation, .halfDayVacation, .sickLeave, .holiday:
            break
            
        case .compensatory:
            overtimeSeconds = -standardSeconds
            
        case .training:
            totalHours = Double(standardSeconds) / 3600.0
        }
        
        if !type.isWorkDay {
            startTime = nil
            endTime = nil
            breakDuration = 0
            bonusAmount = 0
        }
        
        // Synchroniser avec CloudKit
        saveToCloud()
    }
    
    func updateData(startTime: Date?, endTime: Date?, breakDuration: TimeInterval) {
        if type.isWorkDay {
            self.startTime = startTime
            self.endTime = endTime
            self.breakDuration = breakDuration
            
            if let start = startTime { UserSettings.shared.lastStartTime = start }
            if let end = endTime { UserSettings.shared.lastEndTime = end }
        }
        
        calculateHours()
    }
    
    private func saveToCloud() {
        let record = self.toRecord()
        CloudService.shared.save(record) { result in
            switch result {
            case .success(let savedRecord):
                self.cloudKitRecordID = savedRecord.recordID
            case .failure(let error):
                print("Erreur lors de la sauvegarde CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    var formattedTotalHours: String {
        UserSettings.shared.useDecimalHours
        ? String(format: "%.2f", totalHours)
        : formatTimeInterval(totalHours * 3600)
    }
    
    var formattedOvertimeHours: String {
        let seconds = overtimeSeconds
        return UserSettings.shared.useDecimalHours
        ? String(format: "%.2f", Double(seconds) / 3600.0)
        : formatTimeInterval(Double(seconds))
    }
    
    private func formatTimeInterval(_ seconds: Double) -> String {
        let totalMinutes = Int(round(seconds / 60))
        let hours = abs(totalMinutes / 60)
        let minutes = abs(totalMinutes % 60)
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }
    
    var isValid: Bool {
        if type.isWorkDay {
            guard let start = startTime, let end = endTime else { return false }
            return end > start && breakDuration >= 0 && bonusAmount >= 0
        }
        return true
    }
}
