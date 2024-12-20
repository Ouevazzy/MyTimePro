import Foundation

enum VacationType: String, Codable, CaseIterable {
    case rtt = "RTT"
    case congesPayes = "Congés Payés"
    case sansSolde = "Sans Solde"
    case maladie = "Maladie"
    
    var displayName: String {
        switch self {
        case .rtt: return "RTT"
        case .congesPayes: return "Congés Payés"
        case .sansSolde: return "Sans Solde"
        case .maladie: return "Maladie"
        }
    }
}
