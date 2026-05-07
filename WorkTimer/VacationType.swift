import Foundation
import SwiftData

enum VacationType: String, CaseIterable, Codable {
    case vacation = "Congés payés"
    case halfDay = "Demi-journée"
    case unpaid = "Congé sans solde"
    case sickLeave = "Arrêt maladie"
    case compensatory = "Récupération"
    case special = "Congé spécial"
    
    var icon: String {
        switch self {
        case .vacation: return "sun.max.fill"
        case .halfDay: return "sun.min.fill"
        case .unpaid: return "hourglass"
        case .sickLeave: return "cross.case.fill"
        case .compensatory: return "arrow.2.squarepath"
        case .special: return "star.fill"
        }
    }
    
    var color: String {
        switch self {
        case .vacation: return "orange"
        case .halfDay: return "yellow"
        case .unpaid: return "gray"
        case .sickLeave: return "red"
        case .compensatory: return "green"
        case .special: return "purple"
        }
    }
}

enum VacationStatus: String, Codable {
    case pending = "En attente"
    case approved = "Approuvé"
    case rejected = "Refusé"
}

@Model
class Vacation {
    var id: UUID
    var type: String // Type de congé (VacationType rawValue)
    var startDate: Date
    var endDate: Date
    var status: String // VacationStatus rawValue
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var numberOfDays: Double
    
    init(
        type: VacationType,
        startDate: Date,
        endDate: Date,
        status: VacationStatus = .pending,
        note: String? = nil
    ) {
        // Calcul du nombre de jours avant initialisation complète
        let calculatedNumberOfDays = Vacation.calculateNumberOfDays(
            type: type,
            startDate: startDate,
            endDate: endDate
        )
        
        self.id = UUID()
        self.type = type.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.status = status.rawValue
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
        self.numberOfDays = calculatedNumberOfDays
    }
    
    var vacationType: VacationType {
        get { VacationType(rawValue: type) ?? .vacation }
        set { type = newValue.rawValue }
    }
    
    var vacationStatus: VacationStatus {
        get { VacationStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
    
    static func calculateNumberOfDays(
        type: VacationType,
        startDate: Date,
        endDate: Date
    ) -> Double {
        let calendar = Calendar.current
        let settings = UserSettings.shared
        let workingDays = settings.workingDays
        
        var currentDate = startDate
        var days: Double = 0
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            // Convertir de 1-7 (dimanche-samedi) à 0-6 (lundi-dimanche)
            let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
            
            if adjustedWeekday >= 0 && adjustedWeekday < workingDays.count && workingDays[adjustedWeekday] {
                if type == .halfDay {
                    days += 0.5
                } else {
                    days += 1
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    func updateDates(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        self.numberOfDays = Vacation.calculateNumberOfDays(
            type: self.vacationType,
            startDate: startDate,
            endDate: endDate
        )
        self.updatedAt = Date()
    }
}
