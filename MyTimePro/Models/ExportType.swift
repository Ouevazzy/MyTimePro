import Foundation

enum ExportType: Identifiable {
    case monthly
    case annual
    
    var id: Int {
        switch self {
        case .monthly: return 1
        case .annual: return 2
        }
    }
}