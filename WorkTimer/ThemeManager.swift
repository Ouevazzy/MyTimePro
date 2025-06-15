import UIKit
import SwiftUI

class ThemeManager {
    static let shared = ThemeManager()
    
    // @AppStorage("userEnabledDynamicIcon") private var userEnabledDynamicIcon = false
    
    /*
    func updateAppIconForTheme(_ isDarkMode: Bool) {
        // Ne rien faire si l'utilisateur n'a pas activé cette fonctionnalité
        guard userEnabledDynamicIcon else { return }
        
        // Nom de l'icône selon le thème
        let iconName = isDarkMode ? "AppIconDark" : "AppIconLight"
        
        // Ne changez l'icône que si elle est différente de l'icône actuelle
        if UIApplication.shared.alternateIconName != iconName {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("Erreur lors du changement d'icône: \(error.localizedDescription)")
                } else {
                    print("Icône changée avec succès pour le thème \(isDarkMode ? "sombre" : "clair")")
                }
            }
        }
    }
    */
    
    /*
    func enableDynamicIcon(_ enable: Bool) {
        userEnabledDynamicIcon = enable
        if enable {
            // Appliquer immédiatement le thème actuel
            let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            updateAppIconForTheme(isDarkMode)
        } else {
            // Revenir à l'icône par défaut
            UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
        }
    }
    */
    
    /*
    func isDynamicIconEnabled() -> Bool {
        return userEnabledDynamicIcon
    }
    */

    var currentAccentColor: Color {
        return UserSettings.shared.currentAccentColor
    }

    // Helper to get UIColor, useful for UIKit parts if any
    var currentAccentUIColor: UIColor {
        return UserSettings.shared.currentAccentUIColor
    }
}
