import Foundation
import SwiftUI

enum WorkDayType: String, Codable, CaseIterable {
    case work = "workDayType.work"
    case vacation = "workDayType.vacation"
    case halfDayVacation = "workDayType.halfDayVacation"
    case sickLeave = "workDayType.sickLeave"
    case compensatory = "workDayType.compensatory"
    case training = "workDayType.training"
    case holiday = "workDayType.holiday"
    
    /// Localized display name
    var localizedName: String {
        return rawValue.localized
    }
    
    var isWorkDay: Bool { self == .work }
    var isVacation: Bool { self == .vacation || self == .halfDayVacation }
    var isCompensatory: Bool { self == .compensatory }
    var isHalfDay: Bool { self == .halfDayVacation }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .vacation, .halfDayVacation: return "sun.max.fill"
        case .sickLeave: return "cross.case.fill"
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
    
    // Propriété ajoutée pour gérer les heures régulières
    var regularHours: Double? {
        switch self {
        case .work: return 8.0
        case .training: return 8.0
        default: return nil
        }
    }
} 