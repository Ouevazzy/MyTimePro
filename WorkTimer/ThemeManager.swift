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

// MARK: - Design System Guidelines

// MARK: Colors
// Backgrounds:
// - Primary: Color(.systemBackground) - For main view backgrounds.
// - Secondary: Color(.secondarySystemBackground) - For grouped content or elements needing slight separation.
// - Grouped: Color(.systemGroupedBackground) / Color(.secondarySystemGroupedBackground) - For use in Forms or Lists with grouped style.
//
// Text:
// - Primary: Color(.label) - For most text.
// - Secondary: Color(.secondaryLabel) - For supplementary information.
// - Tertiary: Color(.tertiaryLabel) - For disabled text or very subtle annotations.
// - Accent: ThemeManager.shared.currentAccentColor - For interactive elements, highlights.
//
// Semantic Colors:
// - Destructive: Color.red - For actions that delete data or are otherwise destructive.
// - Positive: Color.green - For actions that indicate success or a positive outcome.
// - Warning: Color.orange - For warnings or actions that require caution.
// - Informative: Color.blue (or ThemeManager.shared.currentAccentColor) - For informational messages or highlights.

// MARK: Typography
// Use standard SwiftUI Text Styles. Refer to Apple HIG for visual examples.
// - Large Titles: .largeTitle (for main screen titles if appropriate, like "Home" or "Settings")
// - Titles: .title, .title2, .title3 (for page titles, major section heads, e.g., a specific day's view title)
// - Headlines: .headline (for prominent text, list row titles, card headers, e.g., "Work Hours", "Break Time" in a list)
// - Body: .body (default for text blocks, descriptions, e.g., details of a work entry)
// - Callouts: .callout (for text requiring emphasis, like alerts or important notes within a section)
// - Subheadlines: .subheadline (for secondary info below headlines, e.g., dates under a day title)
// - Footnotes: .footnote (for fine print, captions, e.g., version number, data source attribution)
// - Captions: .caption, .caption2 (for metadata, very small text, e.g., timestamps, short status indicators)
//
// Font Weights:
// - Use .semibold or .medium for emphasis on headlines or important labels where the Text Style itself isn't enough.
// - Example: A .headline with .semibold weight for a key summary figure.
// - Avoid excessive use of bold text. Rely on Text Styles and color for hierarchy and emphasis.
// - Standard weight is generally sufficient for body text and most other use cases.
