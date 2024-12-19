import Foundation

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case week = "Semaine"
    case month = "Mois"
    case year = "Année"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }
}