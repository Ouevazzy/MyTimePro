// TimerManager.swift
import Foundation
import SwiftData
import SwiftUI

// Enum de l'état du timer
enum TimerState: String, Codable {
    case notStarted
    case running
    case paused
    case finished
}

// Structure pour stocker/charger l'état du timer (UserDefaults)
struct TimerData: Codable {
    var startTimestamp: Date?
    var totalPauseDuration: TimeInterval
    var lastPauseStart: Date?
    var timerState: TimerState
    var elapsedTimeAtLastPause: TimeInterval
}

@MainActor
class WorkTimerManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var state: TimerState = .notStarted
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published var showEndDayAlert = false
    @Published var pauseTime: Date?

    // MARK: - Private Properties
    private var timer: Timer?
    private var modelContext: ModelContext
    private var startTimestamp: Date?
    private var totalPauseDuration: TimeInterval = 0
    private var lastPauseStart: Date?
    private var elapsedTimeAtLastPause: TimeInterval = 0

    // MARK: - Computed Properties
    /// Par exemple, si vous avez un paramètre "heures standard journalières" dans votre UserSettings
    private var standardWorkDaySeconds: TimeInterval {
        UserSettings.shared.standardDailyHours * 3600
    }

    var remainingTime: TimeInterval {
        max(0, standardWorkDaySeconds - elapsedTime)
    }

    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSavedState() // Restaure l'état du timer à partir des UserDefaults
    }

    // MARK: - Public Methods
    
    /// Bascule l'état du timer (démarrer, mettre en pause, reprendre ou réinitialiser)
    func toggleTimer() {
        switch state {
        case .notStarted:
            startNewDay()
        case .running:
            pauseTimer()
        case .paused:
            resumeTimer()
        case .finished:
            resetTimer()
        }
    }
    
    /// Appelé lorsque l'utilisateur veut "terminer la journée"
    func attemptEndDay() {
        // Si on est en pause, on affiche une alerte. Sinon, on termine tout de suite.
        if state == .paused {
            pauseTime = lastPauseStart
            showEndDayAlert = true
        } else {
            endDay()
        }
    }

    /// Termine la journée, invalide le timer et enregistre un WorkDay dans la base
    func endDay() {
        showEndDayAlert = false

        // Vérifie qu'on a bien une heure de début
        guard let start = startTimestamp else { return }

        // Crée le WorkDay et remplit les champs
        let workDay = WorkDay()
        workDay.date = Calendar.current.startOfDay(for: Date())
        workDay.startTime = start
        workDay.endTime = (state == .paused) ? lastPauseStart : Date()
        workDay.breakDuration = totalPauseDuration
        
        // Méthode perso : si vous avez un updateData ou similaire
        workDay.updateData(
            startTime: workDay.startTime,
            endTime: workDay.endTime,
            breakDuration: workDay.breakDuration
        )

        // Insère l'objet dans le contexte SwiftData
        modelContext.insert(workDay)
        do {
            try modelContext.save()    // Sauvegarde
            print("WorkDay sauvegardé avec succès.")
        } catch {
            print("Erreur de sauvegarde : \(error)")
        }

        // Très important : on arrête le timer
        timer?.invalidate()
        timer = nil

        withAnimation(.spring(duration: 0.3)) {
            state = .finished
            saveState()  // Sauvegarde l'état dans UserDefaults
        }
    }

    // MARK: - App Lifecycle Methods
    
    /// Appelé quand l'application passe en arrière-plan
    func handleEnterBackground() {
        if state == .running {
            saveState()
        }
    }
    
    /// Appelé quand l'application revient au premier plan
    func handleEnterForeground() {
        if state == .running {
            updateElapsedTime()
            startTimer()
        }
    }

    // MARK: - Private Methods
    
    /// Démarre une nouvelle journée
    private func startNewDay() {
        startTimestamp = Date()
        totalPauseDuration = 0
        lastPauseStart = nil
        elapsedTimeAtLastPause = 0
        state = .running
        startTimer()
        saveState()
    }
    
    /// Met le timer en pause
    private func pauseTimer() {
        timer?.invalidate()
        lastPauseStart = Date()
        elapsedTimeAtLastPause = elapsedTime
        state = .paused
        saveState()
    }
    
    /// Reprend le timer après une pause
    private func resumeTimer() {
        if let pauseStart = lastPauseStart {
            totalPauseDuration += Date().timeIntervalSince(pauseStart)
        }
        lastPauseStart = nil
        state = .running
        startTimer()
        saveState()
    }
    
    /// Réinitialise complètement le timer (utilisé quand l'état est `.finished` et qu'on veut redémarrer)
    private func resetTimer() {
        timer?.invalidate()
        startTimestamp = nil
        totalPauseDuration = 0
        lastPauseStart = nil
        elapsedTimeAtLastPause = 0
        state = .notStarted
        elapsedTime = 0
        saveState()
    }
    
    /// Lance un Timer pour mettre à jour l'elapsedTime toutes les secondes
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
    }
    
    /// Calcule la durée écoulée en tenant compte des pauses
    private func updateElapsedTime() {
        guard let start = startTimestamp else { return }

        if state == .paused {
            // On est en pause : la durée reste figée
            elapsedTime = elapsedTimeAtLastPause
        } else {
            // On est en "running"
            let currentTime = Date()
            let totalElapsed = currentTime.timeIntervalSince(start)
            
            // On ajoute les éventuelles pauses déjà comptées + celle en cours si l'utilisateur n'a pas repris
            var pauseDuration = totalPauseDuration
            if let pauseStart = lastPauseStart {
                pauseDuration += currentTime.timeIntervalSince(pauseStart)
            }
            elapsedTime = totalElapsed - pauseDuration
        }
    }
    
    // MARK: - State Persistence
    
    /// Sauvegarde l'état actuel du timer dans les UserDefaults
    private func saveState() {
        let timerData = TimerData(
            startTimestamp: startTimestamp,
            totalPauseDuration: totalPauseDuration,
            lastPauseStart: lastPauseStart,
            timerState: state,
            elapsedTimeAtLastPause: elapsedTimeAtLastPause
        )
        
        if let encoded = try? JSONEncoder().encode(timerData) {
            UserDefaults.standard.set(encoded, forKey: "timerData")
        }
    }
    
    /// Charge l'état du timer depuis les UserDefaults
    private func loadSavedState() {
        guard
            let data = UserDefaults.standard.data(forKey: "timerData"),
            let timerData = try? JSONDecoder().decode(TimerData.self, from: data)
        else {
            return
        }
        
        state = timerData.timerState
        startTimestamp = timerData.startTimestamp
        totalPauseDuration = timerData.totalPauseDuration
        lastPauseStart = timerData.lastPauseStart
        elapsedTimeAtLastPause = timerData.elapsedTimeAtLastPause
        
        // Si on était en plein "running", on reprend le timer
        if state == .running {
            updateElapsedTime()
            startTimer()
        } else if state == .paused {
            // En pause, on fige l'affichage du chrono
            elapsedTime = elapsedTimeAtLastPause
        }
    }

    // MARK: - Cleanup
    deinit {
        timer?.invalidate()
    }
}
