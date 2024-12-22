import Foundation
import SwiftData

@Model
class VacationType {
    var name: String
    var color: String
    var daysPerYear: Int
    var isPaid: Bool
    
    // Métadonnées CloudKit
    @Attribute(.unique) var id: String
    var modificationDate: Date
    var syncStatus: SyncStatus
    
    init(name: String = "",
         color: String = "#FF0000",
         daysPerYear: Int = 0,
         isPaid: Bool = true) {
        self.name = name
        self.color = color
        self.daysPerYear = daysPerYear
        self.isPaid = isPaid
        
        // Initialisation des métadonnées
        self.id = UUID().uuidString
        self.modificationDate = Date()
        self.syncStatus = .notSynced
    }
    
    // Méthodes utilitaires pour la gestion des couleurs
    var uiColor: UIColor {
        UIColor(hex: color) ?? .red
    }
    
    var colorValue: Color {
        Color(uiColor: uiColor)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        return nil
    }
}

// Méthode de prévisualisation pour SwiftUI
#if DEBUG
extension VacationType {
    static var preview: VacationType {
        VacationType(name: "Congés payés",
                    color: "#FF0000",
                    daysPerYear: 25,
                    isPaid: true)
    }
}
#endif