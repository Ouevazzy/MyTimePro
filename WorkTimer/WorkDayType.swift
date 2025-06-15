import Foundation
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
    
    // Propriété ajoutée pour gérer les heures régulières
    var regularHours: Double? {
        switch self {
        case .work: return 8.0
        case .training: return 8.0
        default: return nil
        }
    }
} 