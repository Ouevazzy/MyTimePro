//
//  PhoneWatchConnectivity.swift
//  WorkTimer
//
//  Pont WatchConnectivity côté iPhone : reçoit les commandes de la montre
//  (chrono, création de journée) et lui pousse un résumé à jour.
//
//  Les messages sont de simples dictionnaires [String: Any] (clés partagées
//  avec la montre) pour éviter de dupliquer des types Codable entre modules.
//

import Foundation
import SwiftData
import WatchConnectivity

/// Clés de protocole partagées avec la montre (doivent rester identiques des deux côtés).
enum WatchKeys {
    static let command = "cmd"            // start | pause | resume | stop | createDay
    static let date = "date"              // TI1970 (début de journée)
    static let start = "start"            // TI1970
    static let end = "end"                // TI1970
    static let breakSeconds = "break"     // secondes
    static let type = "type"              // WorkDayType.rawValue
    static let bonus = "bonus"            // Double

    // Résumé poussé vers la montre
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

final class PhoneWatchConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchConnectivity()

    private var modelContext: ModelContext?
    private var calendar: Calendar = .current

    private override init() { super.init() }

    /// À appeler au lancement de l'app, une fois le container prêt.
    @MainActor
    func start(context: ModelContext) {
        self.modelContext = context
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Résumé → montre

    @MainActor
    func pushSummary() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let snapshot = SiriShortcutsHelper.shared.cachedSummarySnapshot()
        let timer = TimerManager.shared

        var payload: [String: Any] = [
            WatchKeys.overtimeSeconds: snapshot.overtimeSeconds,
            WatchKeys.weeklyHours: snapshot.weeklyHours,
            WatchKeys.vacationBalance: snapshot.vacationBalance,
            WatchKeys.timerActive: timer.isActive,
            WatchKeys.timerPaused: timer.state == .paused,
            WatchKeys.timerPausedAccumulated: timer.pausedAccumulated,
            WatchKeys.useDecimalHours: UserSettings.shared.useDecimalHours,
            WatchKeys.hourlyRate: UserSettings.shared.hourlyRate,
            WatchKeys.currencyCode: Locale.current.currency?.identifier ?? "EUR"
        ]
        payload[WatchKeys.timerStart] = timer.startDate?.timeIntervalSince1970 ?? 0
        payload[WatchKeys.timerPauseStartedAt] = timer.pauseStartedAt?.timeIntervalSince1970 ?? 0

        try? session.updateApplicationContext(payload)
    }

    // MARK: - Commandes ← montre

    private func handle(_ message: [String: Any]) {
        guard let command = message[WatchKeys.command] as? String else { return }
        Task { @MainActor in
            guard let context = modelContext else { return }
            switch command {
            case "start":
                let at = (message[WatchKeys.start] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
                if !TimerManager.shared.isActive { TimerManager.shared.start(at: at) }
            case "pause":
                TimerManager.shared.pause()
            case "resume":
                TimerManager.shared.resume()
            case "stop":
                let at = (message[WatchKeys.end] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
                TimerManager.shared.stopAndSave(in: context, at: at)
            case "createDay":
                applyCreateDay(message, in: context)
            default:
                break
            }
            SiriSummaryCacheService().refresh(using: context)
            pushSummary()
        }
    }

    @MainActor
    private func applyCreateDay(_ message: [String: Any], in context: ModelContext) {
        let typeRaw = message[WatchKeys.type] as? String ?? WorkDayType.work.rawValue
        let type = WorkDayType(rawValue: typeRaw) ?? .work
        let dayDate: Date = (message[WatchKeys.date] as? Double)
            .map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0)) }
            ?? calendar.startOfDay(for: Date())

        let workDay = WorkDay(date: dayDate, type: type)

        if type.isWorkDay {
            guard let startTI = message[WatchKeys.start] as? Double,
                  let endTI = message[WatchKeys.end] as? Double else { return }
            let start = Date(timeIntervalSince1970: startTI)
            let end = Date(timeIntervalSince1970: endTI)
            guard end > start else { return }
            let breakSeconds = message[WatchKeys.breakSeconds] as? Double ?? 0
            workDay.updateData(startTime: start, endTime: end, breakDuration: breakSeconds)
            workDay.bonusAmount = max(0, message[WatchKeys.bonus] as? Double ?? 0)
        } else {
            workDay.updateData(startTime: nil, endTime: nil, breakDuration: 0)
        }

        do {
            context.insert(workDay)
            _ = try WorkDay.reconcileDailyOvertime(in: context, for: [dayDate], calendar: calendar)
            try context.save()
            StatsCache.shared.onWorkDayChanged(workDay, previousDate: dayDate, previousType: type)
        } catch {
            context.rollback()
            ErrorManager.shared.handle(error, context: "WatchCreateDay")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in pushSummary() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }
}
