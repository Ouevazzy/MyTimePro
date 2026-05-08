import Foundation
import SwiftUI

/// Helper pour la localisation des strings
extension String {
    /// Localise une string avec des arguments optionnels
    func localized(_ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, arguments: arguments)
    }
    
    /// Localise une string simple
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
