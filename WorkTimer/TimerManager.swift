import Foundation
import SwiftData
import SwiftUI

enum TimerState: String, Codable {
    case notStarted
    case running
    case paused
    case finished
}

struct TimerData: Codable {
    var startTimestamp: Date?
    var totalPauseDuration: TimeInterval
    var lastPauseStart: Date?
    var timerState: TimerState
    var elapsedTimeAtLastPause: TimeInterval
}

@MainActor
class WorkTimerManager: ObservableObject {
    // MARK: - Singleton
    static let shared = WorkTimerManager(modelContext: ModelContext(try! ModelContainer(for: WorkDay.self)))
    
    // MARK: - Published Properties
    @Published private(set) var state: TimerState = .notStarted
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published var showEndDayAlert = false
    @Published var pauseTime: Date?
    @Published private(set) var currentWorkDay: WorkDay?
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var modelContext: ModelContext
    private var startTimestamp: Date?
    private var totalPauseDuration: TimeInterval = 0
    private var lastPauseStart: Date?
    private var elapsedTimeAtLastPause: TimeInterval = 0
    
    // MARK: - Computed Properties
    private var standardWorkDaySeconds: TimeInterval {
        UserSettings.shared.standardDailyHours * 3600
    }
    
    var remainingTime: TimeInterval {
        max(0, standardWorkDaySeconds - elapsedTime)
    }
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSavedState()
    }
    
    // MARK: - Public Methods
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
        saveState()
    }
    
    func startNewDay() {
        let now = Date()
        startTimestamp = now
        lastPauseStart = nil
        totalPauseDuration = 0
        elapsedTimeAtLastPause = 0
        state = .running
        
        // Créer un nouveau WorkDay
        let newWorkDay = WorkDay(date: now, startTime: now)
        currentWorkDay = newWorkDay
        modelContext.insert(newWorkDay)
        
        startTimer()
        saveState()
    }
    
    func pauseTimer() {
        guard state == .running else { return }
        
        lastPauseStart = Date()
        state = .paused
        timer?.invalidate()
        timer = nil
        
        saveState()
    }
    
    func resumeTimer() {
        guard state == .paused, let pauseStart = lastPauseStart else { return }
        
        let now = Date()
        totalPauseDuration += now.timeIntervalSince(pauseStart)
        lastPauseStart = nil
        state = .running
        
        startTimer()
        saveState()
    }
    
    func endDay() {
        guard let workDay = currentWorkDay else { return }
        
        let now = Date()
        workDay.endTime = now
        workDay.totalHours = elapsedTime / 3600
        
        // Calculer les heures supplémentaires
        let overtime = max(0, elapsedTime - standardWorkDaySeconds)
        workDay.overtimeSeconds = Int(overtime)
        
        state = .finished
        timer?.invalidate()
        timer = nil
        
        saveState()
        saveWorkDay()
    }
    
    func resetTimer() {
        state = .notStarted
        startTimestamp = nil
        lastPauseStart = nil
        totalPauseDuration = 0
        elapsedTimeAtLastPause = 0
        elapsedTime = 0
        currentWorkDay = nil
        
        timer?.invalidate()
        timer = nil
        
        saveState()
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }
    
    private func updateElapsedTime() {
        guard let start = startTimestamp else { return }
        
        let now = Date()
        let totalElapsed = now.timeIntervalSince(start)
        elapsedTime = totalElapsed - totalPauseDuration
        
        // Vérifier si la journée est terminée
        if elapsedTime >= standardWorkDaySeconds {
            showEndDayAlert = true
        }
    }
    
    private func saveState() {
        let timerData = TimerData(
            startTimestamp: startTimestamp,
            totalPauseDuration: totalPauseDuration,
            lastPauseStart: lastPauseStart,
            timerState: state,
            elapsedTimeAtLastPause: elapsedTimeAtLastPause
        )
        
        if let encoded = try? JSONEncoder().encode(timerData) {
            UserDefaults.standard.set(encoded, forKey: "timerState")
        }
    }
    
    private func loadSavedState() {
        guard let data = UserDefaults.standard.data(forKey: "timerState"),
              let timerData = try? JSONDecoder().decode(TimerData.self, from: data) else {
            return
        }
        
        startTimestamp = timerData.startTimestamp
        totalPauseDuration = timerData.totalPauseDuration
        lastPauseStart = timerData.lastPauseStart
        state = timerData.timerState
        elapsedTimeAtLastPause = timerData.elapsedTimeAtLastPause
        
        if state == .running {
            startTimer()
        }
    }
    
    private func saveWorkDay() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving work day: \(error)")
        }
    }
}
