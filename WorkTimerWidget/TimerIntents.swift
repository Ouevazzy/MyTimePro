//
//  TimerIntents.swift
//  WorkTimer + WorkTimerWidget
//
//  Commandes du chrono depuis le widget « Chrono » et le Centre de contrôle.
//  Ce fichier est compilé dans les deux cibles : le widget a besoin des types
//  pour ses boutons, l'app les exécute. En tant que `LiveActivityIntent`, les
//  intentions tournent dans le processus de l'app, où vit `TimerManager`.
//  Chaque cible fournit son propre `TimerIntentHandler`.
//

import AppIntents
import Foundation
import WidgetKit

enum TimerWidgetAction: String {
    case start, pause, resume, stop
}

/// État du chrono publié par l'app dans l'App Group, lu par le widget et la commande.
struct SharedTimerState: Equatable {
    static let appGroupID = "group.jordan-payez.MyTimePro"
    static let widgetKind = "WorkTimerTimerWidget"
    static let controlKind = "jordan-payez.MyTimePro.timerControl"

    /// Fichier JSON dans l'App Group, relu à chaque fois. Les `UserDefaults`
    /// partagés restaient en cache dans le processus du widget : il affichait
    /// encore l'ancien état après un appui.
    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("timer-state.json")
    }

    var startDate: Date?
    var pausedAccumulated: TimeInterval = 0
    var pauseStartedAt: Date?

    var isActive: Bool { startDate != nil }
    var isPaused: Bool { startDate != nil && pauseStartedAt != nil }

    func workedSeconds(at now: Date = Date()) -> TimeInterval {
        guard let startDate else { return 0 }
        var paused = pausedAccumulated
        if let pauseStartedAt { paused += max(0, now.timeIntervalSince(pauseStartedAt)) }
        return max(0, now.timeIntervalSince(startDate) - paused)
    }

    /// Début fictif tel que « maintenant − début » donne le temps travaillé,
    /// pour un compteur qui avance tout seul (`Text(_, style: .timer)`).
    var countingStart: Date? {
        guard let startDate, pauseStartedAt == nil else { return nil }
        return startDate.addingTimeInterval(pausedAccumulated)
    }

    static func read(from url: URL? = fileURL) -> SharedTimerState {
        guard let url, let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return SharedTimerState() }
        return SharedTimerState(startDate: stored.start, pausedAccumulated: max(0, stored.accumulated), pauseStartedAt: stored.pauseStart)
    }

    func write(to url: URL? = Self.fileURL) {
        guard let url else { return }
        let stored = Stored(start: startDate, accumulated: pausedAccumulated, pauseStart: pauseStartedAt)
        try? JSONEncoder().encode(stored).write(to: url, options: .atomic)
    }

    private struct Stored: Codable {
        var start: Date?
        var accumulated: TimeInterval
        var pauseStart: Date?
    }
}

// MARK: - Intentions

struct StartTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "timer.clockIn"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        await TimerIntentHandler.perform(.start)
        return .result()
    }
}

struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "timer.pause"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        await TimerIntentHandler.perform(.pause)
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "timer.resume"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        await TimerIntentHandler.perform(.resume)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "timer.clockOut"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        await TimerIntentHandler.perform(.stop)
        return .result()
    }
}

/// Interrupteur de la commande du Centre de contrôle : allumé = session en cours.
struct SetTimerRunningIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "timer.title"
    static let isDiscoverable = false

    @Parameter(title: "timer.title")
    var value: Bool

    func perform() async throws -> some IntentResult {
        await TimerIntentHandler.perform(value ? .start : .stop)
        return .result()
    }
}
