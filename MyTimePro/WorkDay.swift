import Foundation
import SwiftData
import SwiftUI
import CloudKit

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

@Model
final class WorkDay: Identifiable {
    // MARK: - Properties
    var id: UUID = UUID()
    var date: Date = Date()
    var startTime: Date? = nil
    var endTime: Date? = nil
    var breakDuration: TimeInterval = 3600 // 1 heure par défaut
    var totalHours: Double = 0.0
    var overtimeSeconds: Int = 0
    var typeRawValue: String = WorkDayType.work.rawValue
    var note: String? = ""
    var bonusAmount: Double = 0.0
    
    // Ajout des propriétés pour CloudKit
    var cloudKitRecordID: String?
    var lastModified: Date = Date()
    var isDeleted: Bool = false
    
    var type: WorkDayType {
        get { WorkDayType(rawValue: typeRawValue) ?? .work }
        set {
            typeRawValue = newValue.rawValue
            calculateHours()
            updateLastModified()
        }
    }
    
    // MARK: - Initialization
    init(date: Date = Date(), type: WorkDayType = .work) {
        self.date = date
        self.typeRawValue = type.rawValue
        self.startTime = UserSettings.shared.lastStartTime
        self.endTime = UserSettings.shared.lastEndTime
        self.cloudKitRecordID = "workday_\(id.uuidString)"
        self.lastModified = Date()
        calculateHours()
    }
    
    // MARK: - CloudKit Methods
    func updateLastModified() {
        lastModified = Date()
    }
    
    func toCloudKitRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: cloudKitRecordID ?? "workday_\(id.uuidString)", zoneID: CKRecordZone.ID(zoneName: "WorkTimeZone"))
        let record = CKRecord(recordType: "WorkDay", recordID: recordID)
        
        record.setValue(id.uuidString, forKey: "id")
        record.setValue(date, forKey: "date")
        record.setValue(startTime, forKey: "startTime")
        record.setValue(endTime, forKey: "endTime")
        record.setValue(breakDuration, forKey: "breakDuration")
        record.setValue(totalHours, forKey: "totalHours")
        record.setValue(overtimeSeconds, forKey: "overtimeSeconds")
        record.setValue(typeRawValue, forKey: "typeRawValue")
        record.setValue(note, forKey: "note")
        record.setValue(bonusAmount, forKey: "bonusAmount")
        record.setValue(isDeleted, forKey: "isDeleted")
        record.setValue(lastModified, forKey: "lastModified")
        
        return record
    }
    
    static func fromCloudKitRecord(_ record: CKRecord) -> WorkDay {
        let workDay = WorkDay()
        
        if let idString = record.value(forKey: "id") as? String,
           let uuid = UUID(uuidString: idString) {
            workDay.id = uuid
        }
        
        if let date = record.value(forKey: "date") as? Date {
            workDay.date = date
        }
        
        workDay.startTime = record.value(forKey: "startTime") as? Date
        workDay.endTime = record.value(forKey: "endTime") as? Date
        
        if let breakDuration = record.value(forKey: "breakDuration") as? TimeInterval {
            workDay.breakDuration = breakDuration
        }
        
        if let totalHours = record.value(forKey: "totalHours") as? Double {
            workDay.totalHours = totalHours
        }
        
        if let overtimeSeconds = record.value(forKey: "overtimeSeconds") as? Int {
            workDay.overtimeSeconds = overtimeSeconds
        }
        
        if let typeRawValue = record.value(forKey: "typeRawValue") as? String {
            workDay.typeRawValue = typeRawValue
        }
        
        workDay.note = record.value(forKey: "note") as? String
        
        if let bonusAmount = record.value(forKey: "bonusAmount") as? Double {
            workDay.bonusAmount = bonusAmount
        }
        
        if let isDeleted = record.value(forKey: "isDeleted") as? Bool {
            workDay.isDeleted = isDeleted
        }
        
        if let lastModified = record.value(forKey: "lastModified") as? Date {
            workDay.lastModified = lastModified
        }
        
        workDay.cloudKitRecordID = record.recordID.recordName
        
        return workDay
    }
    
    // MARK: - Calculation Methods
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
        
        updateLastModified()
    }
    
    // MARK: - Update Methods
    func updateData(startTime: Date?, endTime: Date?, breakDuration: TimeInterval) {
        if type.isWorkDay {
            self.startTime = startTime
            self.endTime = endTime
            self.breakDuration = breakDuration
            
            if let start = startTime { UserSettings.shared.lastStartTime = start }
            if let end = endTime { UserSettings.shared.lastEndTime = end }
        }
        
        calculateHours()
        updateLastModified()
    }
    
    // MARK: - Formatting Methods
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
