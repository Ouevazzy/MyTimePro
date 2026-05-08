import SwiftUI

final class ThemeManager {
    static let shared = ThemeManager()

    @AppStorage("userEnabledDynamicIcon") private var userEnabledDynamicIcon = false

    private init() {}

    func updateAppIconForTheme(_ isDarkMode: Bool) {
        _ = isDarkMode
        AppLogger.debug("App icon appearance is handled by the asset catalog variants", category: AppLogger.general)
    }

    func enableDynamicIcon(_ enable: Bool) {
        _ = enable
        userEnabledDynamicIcon = false
        AppLogger.debug("Runtime alternate icons are disabled; iOS uses Default/Dark/Tinted app icon variants", category: AppLogger.general)
    }

    func isDynamicIconEnabled() -> Bool {
        false
    }
}
