import Foundation
import WidgetKit

/// Publie un instantané des stats vers le widget via l'App Group.
///
/// ⚠️ Prérequis (une fois le target widget créé dans Xcode) :
/// 1. Capability "App Groups" sur le target WorkTimer ET le target widget
/// 2. Même identifiant que `appGroupID` ci-dessous
///
/// Tant que l'App Group n'existe pas, `UserDefaults(suiteName:)` retourne nil
/// et ce service est un no-op silencieux : aucun impact sur l'app.
enum WidgetSnapshotService {

    /// Doit correspondre à l'App Group créé dans Signing & Capabilities.
    static let appGroupID = "group.jordan-payez.MyTimePro"

    enum Keys {
        static let weeklyHours = "widget.weeklyHours"
        static let overtimeSeconds = "widget.overtimeSeconds"
        static let vacationBalance = "widget.vacationBalance"
        static let updatedAt = "widget.updatedAt"
    }

    /// Écrit l'instantané partagé et demande le rafraîchissement des timelines.
    /// Appelé depuis SiriSummaryCacheService.refresh — le point de passage
    /// unique après chaque mutation de données.
    static func write(_ snapshot: SiriSummarySnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(snapshot.weeklyHours, forKey: Keys.weeklyHours)
        defaults.set(snapshot.overtimeSeconds, forKey: Keys.overtimeSeconds)
        defaults.set(snapshot.vacationBalance, forKey: Keys.vacationBalance)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.updatedAt)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
