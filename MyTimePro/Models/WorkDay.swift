import Foundation
import SwiftData

@Model
class WorkDay: Identifiable {
    var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var pauseDuration: TimeInterval
    var totalDuration: TimeInterval
    var isVacation: Bool
    var vacationType: VacationType?
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         startTime: Date = Date(),
         endTime: Date = Date(),
         pauseDuration: TimeInterval = 0,
         totalDuration: TimeInterval = 0,
         isVacation: Bool = false,
         vacationType: VacationType? = nil) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.pauseDuration = pauseDuration
        self.totalDuration = totalDuration
        self.isVacation = isVacation
        self.vacationType = vacationType
    }
    
    func update(from other: WorkDay) {
        self.date = other.date
        self.startTime = other.startTime
        self.endTime = other.endTime
        self.pauseDuration = other.pauseDuration
        self.totalDuration = other.totalDuration
        self.isVacation = other.isVacation
        self.vacationType = other.vacationType
    }
}
