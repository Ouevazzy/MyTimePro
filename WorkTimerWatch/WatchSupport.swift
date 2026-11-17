//
//  WatchSupport.swift
//  WorkTimerWatch
//
//  Types et helpers de formatage pour l'app montre.
//

import SwiftUI

/// Raccourci de localisation pour l'app montre (clés dans WorkTimerWatch/*.lproj).
extension String {
    var loc: String { NSLocalizedString(self, comment: "") }
}

/// Types de journée proposés à la saisie sur la montre.
/// `raw` doit correspondre à `WorkDayType.rawValue` côté iPhone.
enum WatchDayType: String, CaseIterable, Identifiable {
    case work = "workDayType.work"
    case vacation = "workDayType.vacation"
    case halfDayVacation = "workDayType.halfDayVacation"
    case sickLeave = "workDayType.sickLeave"
    case holiday = "workDayType.holiday"
    case compensatory = "workDayType.compensatory"

    var id: String { rawValue }
    var isWork: Bool { self == .work }

    var label: String {
        switch self {
        case .work: return "watch.daytype.work".loc
        case .vacation: return "watch.daytype.vacation".loc
        case .halfDayVacation: return "watch.daytype.halfVacation".loc
        case .sickLeave: return "watch.daytype.sick".loc
        case .holiday: return "watch.daytype.holiday".loc
        case .compensatory: return "watch.daytype.comp".loc
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .vacation: return "sun.max.fill"
        case .halfDayVacation: return "sun.haze.fill"
        case .sickLeave: return "cross.case.fill"
        case .holiday: return "star.fill"
        case .compensatory: return "arrow.counterclockwise"
        }
    }
}

enum WatchFormat {
    /// HH:MM:SS pour le chrono en direct.
    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// Solde d'heures signé (+1h30 / -0h45), à partir de secondes.
    static func signedHours(seconds: Int, decimal: Bool) -> String {
        let sign = seconds < 0 ? "-" : "+"
        if decimal {
            return String(format: "%@%.2fh", sign, abs(Double(seconds)) / 3600.0)
        }
        let totalMinutes = abs(seconds) / 60
        return String(format: "%@%dh%02d", sign, totalMinutes / 60, totalMinutes % 60)
    }

    /// Heures positives (ex. heures de la semaine).
    static func hours(_ hours: Double, decimal: Bool) -> String {
        if decimal { return String(format: "%.2fh", hours) }
        let totalMinutes = Int((hours * 60).rounded())
        return String(format: "%dh%02d", totalMinutes / 60, totalMinutes % 60)
    }

    static func days(_ value: Double) -> String {
        String(format: "%.1f j", value)
    }
}
