import Foundation
import SwiftData
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

@Model
final class WorkDay {
    // MARK: - Properties
    var id: UUID
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var breakDuration: TimeInterval
    var totalHours: Double
    var overtimeSeconds: Int
    var typeRawValue: String
    var note: String?
    var bonusAmount: Double
    
    // CloudKit properties
    var cloudKitRecordID: String
    var lastModified: Date
    var isDeleted: Bool
    
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
        let uuid = UUID()
        
        self.id = uuid
        self.date = date
        self.startTime = UserSettings.shared.lastStartTime
        self.endTime = UserSettings.shared.lastEndTime
        self.breakDuration = 3600 // 1 heure par défaut
        self.totalHours = 0.0
        self.overtimeSeconds = 0
        self.typeRawValue = type.rawValue
        self.note = ""
        self.bonusAmount = 0.0
        self.cloudKitRecordID = "workday_\(uuid.uuidString)"
        self.lastModified = Date()
        self.isDeleted = false
        
        calculateHours()
    }
    
    // MARK: - CloudKit Methods
    func updateLastModified() {
        lastModified = Date()
    }
    
    // Mark entry as deleted instead of actual deletion
    func markAsDeleted() {
        isDeleted = true
        updateLastModified()
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
