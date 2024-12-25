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
    // Identifiant unique
    var id: UUID = UUID()
    var cloudKitRecordID: String?
    
    // Dates de création et modification
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isDeleted: Bool = false
    
    // Informations sur la journée
    var date: Date = Date()
    var startTime: Date?
    var endTime: Date?
    var breakDuration: TimeInterval = 3600 // 1 heure par défaut
    var totalHours: Double = 0.0
    var overtimeSeconds: Int = 0
    var typeRawValue: String = WorkDayType.work.rawValue
    var note: String?
    var bonusAmount: Double = 0.0
    
    var type: WorkDayType {
        get {
            WorkDayType(rawValue: typeRawValue) ?? .work
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        breakDuration: TimeInterval = 3600,
        totalHours: Double = 0.0,
        overtimeSeconds: Int = 0,
        type: WorkDayType = .work,
        note: String? = nil,
        bonusAmount: Double = 0.0,
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.breakDuration = breakDuration
        self.totalHours = totalHours
        self.overtimeSeconds = overtimeSeconds
        self.type = type
        self.note = note
        self.bonusAmount = bonusAmount
        self.cloudKitRecordID = cloudKitRecordID
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isDeleted = false
    }
    
    func calculateHours() {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        
        // Par défaut, pas d'heures standard
        var standardSeconds = 0
        
        // Calcul des heures standard pour les jours de travail et compensatoires
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
            // Pas de comptage d'heures
            break
            
        case .compensatory:
            overtimeSeconds = -standardSeconds
            
        case .training:
            totalHours = Double(standardSeconds) / 3600.0
        }
        
        // Réinitialisation pour les journées non travaillées
        if !type.isWorkDay {
            startTime = nil
            endTime = nil
            breakDuration = 0
            bonusAmount = 0
        }
        
        modifiedAt = Date()
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
        modifiedAt = Date()
    }
    
    // Méthodes pour CloudKit
    func prepareForCloudKit() -> [String: Any] {
        var record: [String: Any] = [
            "id": id.uuidString,
            "date": date,
            "typeRawValue": typeRawValue,
            "breakDuration": breakDuration,
            "totalHours": totalHours,
            "overtimeSeconds": overtimeSeconds,
            "bonusAmount": bonusAmount,
            "createdAt": createdAt,
            "modifiedAt": modifiedAt,
            "isDeleted": isDeleted
        ]
        
        if let start = startTime { record["startTime"] = start }
        if let end = endTime { record["endTime"] = end }
        if let note = note { record["note"] = note }
        if let recordID = cloudKitRecordID { record["recordID"] = recordID }
        
        return record
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
}

// MARK: - Validation Properties
extension WorkDay {
    var isValid: Bool {
        if type.isWorkDay {
            guard let start = startTime, let end = endTime else { return false }
            return end > start && breakDuration >= 0 && bonusAmount >= 0
        }
        return true
    }
    
    var shouldSync: Bool {
        modifiedAt > createdAt && !isDeleted
    }
}
