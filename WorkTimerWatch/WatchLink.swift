//
//  WatchLink.swift
//  WorkTimerWatch
//
//  Pont WatchConnectivity côté montre : reçoit le résumé de l'iPhone et lui
//  envoie les commandes (chrono, création de journée).
//

import Foundation
import Observation
import WatchConnectivity

/// Clés de protocole partagées avec l'iPhone (doivent rester identiques des deux côtés).
enum WatchKeys {
    static let command = "cmd"
    static let date = "date"
    static let start = "start"
    static let end = "end"
    static let breakSeconds = "break"
    static let type = "type"
    static let bonus = "bonus"

    static let overtimeSeconds = "overtimeSeconds"
    static let weeklyHours = "weeklyHours"
    static let vacationBalance = "vacationBalance"
    static let timerActive = "timerActive"
    static let timerStart = "timerStart"
    static let timerPaused = "timerPaused"
    static let timerPausedAccumulated = "timerPausedAccumulated"
    static let timerPauseStartedAt = "timerPauseStartedAt"
    static let useDecimalHours = "useDecimalHours"
    static let currencyCode = "currencyCode"
    static let hourlyRate = "hourlyRate"
}

@Observable
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    // Résumé reçu de l'iPhone
    var overtimeSeconds: Int = 0
    var weeklyHours: Double = 0
    var vacationBalance: Double = 0
    var useDecimalHours: Bool = false
    var currencyCode: String = "EUR"
    var hourlyRate: Double = 0

    // État du chrono (miroir de l'iPhone, avec retour local immédiat)
    var timerActive: Bool = false
    var timerStart: Date?
    var timerPaused: Bool = false
    var pausedAccumulated: TimeInterval = 0
    var pauseStartedAt: Date?

    var isReachable: Bool = false

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Calcul du temps écoulé (identique à l'iPhone)
    func workedSeconds(at now: Date = Date()) -> TimeInterval {
        guard let start = timerStart else { return 0 }
        let gross = max(0, now.timeIntervalSince(start))
        return max(0, gross - breakSeconds(at: now))
    }

    func breakSeconds(at now: Date = Date()) -> TimeInterval {
        var total = pausedAccumulated
        if let pauseStart = pauseStartedAt { total += max(0, now.timeIntervalSince(pauseStart)) }
        return total
    }

    // MARK: - Commandes → iPhone (avec retour local optimiste)

    func startTimer() {
        let now = Date()
        timerActive = true
        timerStart = now
        timerPaused = false
        pausedAccumulated = 0
        pauseStartedAt = nil
        send([WatchKeys.command: "start", WatchKeys.start: now.timeIntervalSince1970])
    }

    func pauseTimer() {
        guard timerActive, !timerPaused else { return }
        timerPaused = true
        pauseStartedAt = Date()
        send([WatchKeys.command: "pause"])
    }

    func resumeTimer() {
        guard let pauseStart = pauseStartedAt else { return }
        pausedAccumulated += max(0, Date().timeIntervalSince(pauseStart))
        pauseStartedAt = nil
        timerPaused = false
        send([WatchKeys.command: "resume"])
    }

    func stopTimer() {
        let now = Date()
        timerActive = false
        timerStart = nil
        timerPaused = false
        pausedAccumulated = 0
        pauseStartedAt = nil
        send([WatchKeys.command: "stop", WatchKeys.end: now.timeIntervalSince1970])
    }

    func createDay(date: Date, type: String, start: Date, end: Date, breakSeconds: TimeInterval, bonus: Double) {
        send([
            WatchKeys.command: "createDay",
            WatchKeys.date: date.timeIntervalSince1970,
            WatchKeys.type: type,
            WatchKeys.start: start.timeIntervalSince1970,
            WatchKeys.end: end.timeIntervalSince1970,
            WatchKeys.breakSeconds: breakSeconds,
            WatchKeys.bonus: bonus
        ])
    }

    private func send(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { _ in
                session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Réception du résumé

    private func apply(_ context: [String: Any]) {
        Task { @MainActor in
            if let v = context[WatchKeys.overtimeSeconds] as? Int { overtimeSeconds = v }
            if let v = context[WatchKeys.weeklyHours] as? Double { weeklyHours = v }
            if let v = context[WatchKeys.vacationBalance] as? Double { vacationBalance = v }
            if let v = context[WatchKeys.useDecimalHours] as? Bool { useDecimalHours = v }
            if let v = context[WatchKeys.currencyCode] as? String { currencyCode = v }
            if let v = context[WatchKeys.hourlyRate] as? Double { hourlyRate = v }

            if let active = context[WatchKeys.timerActive] as? Bool {
                timerActive = active
                let startTI = context[WatchKeys.timerStart] as? Double ?? 0
                timerStart = (active && startTI > 0) ? Date(timeIntervalSince1970: startTI) : nil
                timerPaused = context[WatchKeys.timerPaused] as? Bool ?? false
                pausedAccumulated = context[WatchKeys.timerPausedAccumulated] as? Double ?? 0
                let pauseTI = context[WatchKeys.timerPauseStartedAt] as? Double ?? 0
                pauseStartedAt = pauseTI > 0 ? Date(timeIntervalSince1970: pauseTI) : nil
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in isReachable = session.isReachable }
        apply(session.receivedApplicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in isReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }
}
