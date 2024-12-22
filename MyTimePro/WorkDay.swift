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
final class WorkDay: Identifiable {
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

    var type: WorkDayType {
        get { WorkDayType(rawValue: typeRawValue) ?? .work }
        set {
            typeRawValue = newValue.rawValue
            calculateHours()
        }
    }
    
    init(date: Date = Date(), type: WorkDayType = .work) {
        self.date = date
        self.typeRawValue = type.rawValue
        self.startTime = UserSettings.shared.lastStartTime
        self.endTime = UserSettings.shared.lastEndTime
        calculateHours()
    }
    
    func calculateHours() {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        
        // Par défaut, on considère qu'il n'y a pas d'heures standard pour ce jour
        var standardSeconds = 0
        
        // Si c'est un jour de travail ou une journée compensatoire, on calcule les heures standard
        if type == .work || type == .compensatory {
            // Convertir le jour de la semaine de 1-7 (dimanche-samedi) à 0-6 (lundi-dimanche)
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
            
            // Si le jour est configuré comme travaillé dans les paramètres
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
            // Ne compte pas dans les heures
            break
            
        case .compensatory:
            // Déduire les heures standard des heures supplémentaires
            overtimeSeconds = -standardSeconds
            
        case .training:
            totalHours = Double(standardSeconds) / 3600.0
        }
        
        // Réinitialiser les heures de début/fin/pause pour les journées non travaillées
        if !type.isWorkDay {
            startTime = nil
            endTime = nil
            breakDuration = 0
            bonusAmount = 0
        }
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
