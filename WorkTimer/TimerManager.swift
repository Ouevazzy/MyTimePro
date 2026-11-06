//
//  TimerManager.swift
//  WorkTimer
//
//  Chronomètre en direct : pointage arrivée/départ avec compteur qui tourne.
//  L'état est persisté dans UserDefaults pour survivre à la fermeture de l'app.
//

import SwiftUI
import SwiftData

/// Source de vérité unique du chronomètre « en direct ».
///
/// Contrairement à la saisie manuelle (début/fin figés), ce gestionnaire mesure
/// une session de travail en cours : heure de pointage, temps de pause cumulé et
/// pause courante éventuelle. Au départ, il matérialise la session mesurée en une
/// entrée `WorkDay` enregistrée, puis se réinitialise.
@Observable
final class TimerManager {

    // MARK: - Singleton
    static let shared = TimerManager()

    // MARK: - State
    enum RunState: Equatable { case idle, running, paused }

    /// Instant de pointage de l'arrivée. `nil` = aucune session en cours.
    private(set) var startDate: Date?
    /// Secondes de pause déjà cumulées (pauses terminées).
    private(set) var pausedAccumulated: TimeInterval = 0
    /// Début de la pause courante, si l'utilisateur est en pause.
    private(set) var pauseStartedAt: Date?

    /// Durée minimale d'une session pour être enregistrée (évite les pointages accidentels).
    private let minimumSessionSeconds: TimeInterval = 60

    // MARK: - Persistence
    private enum Keys {
        static let startDate = "liveTimer.startDate"
        static let pausedAccumulated = "liveTimer.pausedAccumulated"
        static let pauseStartedAt = "liveTimer.pauseStartedAt"
    }
    private let store = UserDefaults.standard

    // MARK: - Init
    private init() { load() }

    // MARK: - Derived state
    var state: RunState {
        guard startDate != nil else { return .idle }
        return pauseStartedAt == nil ? .running : .paused
    }

    var isActive: Bool { startDate != nil }

    /// Secondes travaillées (brut − pauses) à l'instant donné.
    func workedSeconds(at now: Date = Date()) -> TimeInterval {
        guard let start = startDate else { return 0 }
        let gross = max(0, now.timeIntervalSince(start))
        return max(0, gross - breakSeconds(at: now))
    }

    /// Secondes de pause totales (cumulées + pause courante) à l'instant donné.
    func breakSeconds(at now: Date = Date()) -> TimeInterval {
        var total = pausedAccumulated
        if let pauseStart = pauseStartedAt {
            total += max(0, now.timeIntervalSince(pauseStart))
        }
        return total
    }

    // MARK: - Commands
    func start(at date: Date = Date()) {
        guard startDate == nil else { return }
        startDate = date
        pausedAccumulated = 0
        pauseStartedAt = nil
        persist()
    }

    func pause(at date: Date = Date()) {
        guard startDate != nil, pauseStartedAt == nil else { return }
        pauseStartedAt = date
        persist()
    }

    func resume(at date: Date = Date()) {
        guard let pauseStart = pauseStartedAt else { return }
        pausedAccumulated += max(0, date.timeIntervalSince(pauseStart))
        pauseStartedAt = nil
        persist()
    }

    func reset() {
        startDate = nil
        pausedAccumulated = 0
        pauseStartedAt = nil
        persist()
    }

    // MARK: - Finalisation

    enum StopResult: Equatable {
        case saved          // Une entrée WorkDay a été créée
        case tooShort       // Session trop courte, ignorée
        case notRunning     // Aucune session en cours
        case failed         // Erreur d'enregistrement
    }

    /// Clôture la session en cours et l'enregistre comme une entrée `WorkDay` de travail.
    /// Renvoie l'entrée créée (pour édition éventuelle) et le résultat de l'opération.
    @MainActor
    @discardableResult
    func stopAndSave(
        in context: ModelContext,
        at endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (workDay: WorkDay?, result: StopResult) {
        guard let start = startDate else { return (nil, .notRunning) }

        let end = max(endDate, start)
        let totalBreak = breakSeconds(at: end)
        let worked = max(0, end.timeIntervalSince(start) - totalBreak)

        // Session trop courte (p. ex. pointage accidentel) : on annule sans enregistrer.
        guard worked >= minimumSessionSeconds else {
            reset()
            return (nil, .tooShort)
        }

        let dayDate = calendar.startOfDay(for: start)
        let workDay = WorkDay(date: dayDate, type: .work)
        workDay.updateData(startTime: start, endTime: end, breakDuration: totalBreak)

        do {
            context.insert(workDay)
            _ = try WorkDay.reconcileDailyOvertime(in: context, for: [dayDate], calendar: calendar)
            try context.save()

            UserSettings.shared.updateLastUsedTimes(start: start, end: end, breakDuration: totalBreak)
            StatsCache.shared.onWorkDayChanged(workDay, previousDate: dayDate, previousType: .work)
            SiriSummaryCacheService(calendar: calendar).refresh(using: context)
            Haptic.notification(.success)

            reset()
            return (workDay, .saved)
        } catch {
            context.rollback()
            ErrorManager.shared.handle(error, context: "TimerStopAndSave")
            return (nil, .failed)
        }
    }

    // MARK: - Persistence helpers
    private func persist() {
        if let startDate {
            store.set(startDate.timeIntervalSince1970, forKey: Keys.startDate)
        } else {
            store.removeObject(forKey: Keys.startDate)
        }
        store.set(pausedAccumulated, forKey: Keys.pausedAccumulated)
        if let pauseStartedAt {
            store.set(pauseStartedAt.timeIntervalSince1970, forKey: Keys.pauseStartedAt)
        } else {
            store.removeObject(forKey: Keys.pauseStartedAt)
        }

        // Tient la montre informée de l'état du chrono.
        Task { @MainActor in PhoneWatchConnectivity.shared.pushSummary() }
    }

    private func load() {
        if store.object(forKey: Keys.startDate) != nil {
            let interval = store.double(forKey: Keys.startDate)
            startDate = interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
        pausedAccumulated = max(0, store.double(forKey: Keys.pausedAccumulated))
        if store.object(forKey: Keys.pauseStartedAt) != nil {
            let interval = store.double(forKey: Keys.pauseStartedAt)
            pauseStartedAt = interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
    }
}
