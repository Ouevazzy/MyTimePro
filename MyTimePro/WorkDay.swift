import Foundation
import SwiftData

@Model
class WorkDay {
    // Propriétés principales
    var date: Date
    var startTime: Date
    var endTime: Date?
    var totalTime: TimeInterval
    var notes: String
    var breaks: [Break]
    var isVacation: Bool
    var vacationType: VacationType?
    
    // Métadonnées CloudKit
    @Attribute(.unique) var id: String
    var modificationDate: Date
    var syncStatus: SyncStatus
    
    // Propriétés calculées
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var workDuration: TimeInterval {
        guard let end = endTime else { return 0 }
        let breakDuration = breaks.reduce(0) { $0 + $1.duration }
        return end.timeIntervalSince(startTime) - breakDuration
    }
    
    // Initialisation
    init(date: Date = Date(), 
         startTime: Date = Date(),
         endTime: Date? = nil,
         totalTime: TimeInterval = 0,
         notes: String = "",
         breaks: [Break] = [],
         isVacation: Bool = false,
         vacationType: VacationType? = nil) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.totalTime = totalTime
        self.notes = notes
        self.breaks = breaks
        self.isVacation = isVacation
        self.vacationType = vacationType
        
        // Initialisation des métadonnées
        self.id = UUID().uuidString
        self.modificationDate = Date()
        self.syncStatus = .notSynced
    }
}

// Modèle pour les pauses
@Model
class Break {
    var startTime: Date
    var endTime: Date?
    @Relationship(inverse: \WorkDay.breaks) var workDay: WorkDay?
    
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
    
    init(startTime: Date = Date(), endTime: Date? = nil) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

// État de synchronisation
enum SyncStatus: Int, Codable {
    case notSynced = 0
    case syncing = 1
    case synced = 2
    case failed = 3
}

// Extensions pour faciliter le tri et la recherche
extension WorkDay {
    static func byDate(ascending: Bool = true) -> SortDescriptor<WorkDay> {
        return SortDescriptor(\WorkDay.date, order: ascending ? .forward : .reverse)
    }
    
    // Fonction utilitaire pour la gestion du temps
    func calculateTotalTime() -> TimeInterval {
        guard let end = endTime else { return 0 }
        let totalBreakTime = breaks.reduce(0) { $0 + $1.duration }
        return end.timeIntervalSince(startTime) - totalBreakTime
    }
    
    // Méthodes pour la gestion des pauses
    func startBreak() {
        let newBreak = Break(startTime: Date())
        breaks.append(newBreak)
        modificationDate = Date()
        syncStatus = .notSynced
    }
    
    func endBreak() {
        if let currentBreak = breaks.last, currentBreak.endTime == nil {
            currentBreak.endTime = Date()
            modificationDate = Date()
            syncStatus = .notSynced
        }
    }
}
