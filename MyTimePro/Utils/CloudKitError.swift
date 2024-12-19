import Foundation

enum CloudKitError: LocalizedError {
    case accountNotAvailable
    case dataNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case subscriptionFailed(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "Compte iCloud non disponible"
        case .dataNotFound:
            return "Données non trouvées"
        case .saveFailed(let error):
            return "Erreur de sauvegarde: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Erreur de récupération: \(error.localizedDescription)"
        case .subscriptionFailed(let error):
            return "Erreur d'abonnement: \(error.localizedDescription)"
        case .unknown(let error):
            return "Erreur inconnue: \(error.localizedDescription)"
        }
    }
}
