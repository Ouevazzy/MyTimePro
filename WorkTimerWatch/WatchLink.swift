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

    var lastSubmission = UserDefaults.standard.string(forKey: "watch.lastSubmission")
    var submissionStatus = UserDefaults.standard.string(forKey: "watch.submissionStatus") ?? ""
    private var pendingTimerID = UserDefaults.standard.string(forKey: "watch.pendingTimerID")

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if pendingTimerID != nil, let state = UserDefaults.standard.dictionary(forKey: "watch.pendingTimerState") {
            let start = state["start"] as? Double ?? 0
            let pause = state["pause"] as? Double ?? 0
            timerActive = start > 0
            timerStart = timerActive ? Date(timeIntervalSince1970: start) : nil
            timerPaused = pause > 0
            pauseStartedAt = timerPaused ? Date(timeIntervalSince1970: pause) : nil
            pausedAccumulated = state["accumulated"] as? Double ?? 0
        }
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
        sendTimer("start", at: now, sessionStart: now)
    }

    func pauseTimer() {
        guard timerActive, !timerPaused else { return }
        timerPaused = true
        let now = Date()
        pauseStartedAt = now
        sendTimer("pause", at: now, sessionStart: timerStart)
    }

    func resumeTimer() {
        guard let pauseStart = pauseStartedAt else { return }
        let now = Date()
        pausedAccumulated += max(0, now.timeIntervalSince(pauseStart))
        pauseStartedAt = nil
        timerPaused = false
        sendTimer("resume", at: now, sessionStart: timerStart)
    }

    func stopTimer() {
        let now = Date()
        let start = timerStart
        timerActive = false
        timerStart = nil
        timerPaused = false
        pausedAccumulated = 0
        pauseStartedAt = nil
        sendTimer("stop", at: now, sessionStart: start)
    }

    func createDay(date: Date, type: String, start: Date, end: Date, breakSeconds: TimeInterval, bonus: Double) {
        let id = UUID().uuidString
        lastSubmission = id
        UserDefaults.standard.set(id, forKey: "watch.lastSubmission")
        setSubmissionStatus("pending")
        WCSession.default.transferUserInfo([
            "submissionID": id,
            WatchKeys.command: "createDay",
            WatchKeys.date: date.timeIntervalSince1970,
            WatchKeys.type: type,
            WatchKeys.start: start.timeIntervalSince1970,
            WatchKeys.end: end.timeIntervalSince1970,
            WatchKeys.breakSeconds: breakSeconds,
            WatchKeys.bonus: bonus
        ])
    }

    private func sendTimer(_ command: String, at date: Date, sessionStart: Date?) {
        guard let sessionStart else { return }
        let id = UUID().uuidString
        pendingTimerID = id
        UserDefaults.standard.set(id, forKey: "watch.pendingTimerID")
        // One ordered transport also preserves pause/resume order across reconnection.
        WCSession.default.transferUserInfo([
            WatchKeys.command: command, "timerCommandID": id,
            WatchKeys.start: sessionStart.timeIntervalSince1970,
            WatchKeys.end: date.timeIntervalSince1970
        ])
        let state: [String: Any] = [
            "start": timerStart?.timeIntervalSince1970 ?? 0,
            "pause": pauseStartedAt?.timeIntervalSince1970 ?? 0,
            "accumulated": pausedAccumulated
        ]
        UserDefaults.standard.set(state, forKey: "watch.pendingTimerState")
    }

    private func setSubmissionStatus(_ status: String) {
        submissionStatus = status
        UserDefaults.standard.set(status, forKey: "watch.submissionStatus")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let id = userInfo["submissionID"] as? String, let saved = userInfo["saved"] as? Bool else { return }
        Task { @MainActor in
            if lastSubmission == id { setSubmissionStatus(saved ? "saved" : "failed") }
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

            if let pendingTimerID {
                guard context["lastTimerCommandID"] as? String == pendingTimerID else { return }
                self.pendingTimerID = nil
                UserDefaults.standard.removeObject(forKey: "watch.pendingTimerID")
            }
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
