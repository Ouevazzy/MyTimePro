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
    var startTimestamp: Date
    var totalPauseDuration: TimeInterval
    var lastPauseStart: Date?
    var state: TimerState
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
    init() {
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
    }
    
    func attemptEndDay() {
        if state == .paused {
            pauseTime = lastPauseStart
            showEndDayAlert = true
        } else {
            endDay()
        }
    }
    
    func endDay() async {
        showEndDayAlert = false
        
        if state == .running {
            updateElapsedTime()
        }
        
        guard let start = startTimestamp else { return }
        
        let workDay = WorkDay()
        workDay.date = Calendar.current.startOfDay(for: Date())
        workDay.startTime = start
        
        if state == .paused {
            workDay.endTime = lastPauseStart
            workDay.breakDuration = totalPauseDuration
        } else {
            workDay.endTime = Date()
            workDay.breakDuration = totalPauseDuration
        }
        
        await workDay.updateData(
            startTime: workDay.startTime,
            endTime: workDay.endTime,
            breakDuration: workDay.breakDuration
        )
        
        // Sauvegarde SwiftData et synchronisation CloudKit
        if let modelContext = getModelContext() {
            modelContext.insert(workDay)
            do {
                try modelContext.save()
                // Synchronisation après sauvegarde
                await CloudService.shared.requestSync()
            } catch {
                print("Failed to save work day: \(error.localizedDescription)")
            }
        }
        
        state = .finished
        saveState()
    }
    
    // MARK: - App Lifecycle Methods
    func handleEnterBackground() async {
        if state == .running {
            saveState()
            await CloudService.shared.requestSync()
        }
    }
    
    func handleEnterForeground() async {
        if state == .running {
            updateElapsedTime()
            startTimer()
        }
    }
    
    // MARK: - Private Methods
    private func getModelContext() -> ModelContext? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return nil
        }
        
        let environment = EnvironmentValues()
        return environment.modelContext
    }
    
    private func startNewDay() {
        startTimestamp = Date()
        totalPauseDuration = 0
        lastPauseStart = nil
        elapsedTimeAtLastPause = 0
        state = .running
        startTimer()
        saveState()
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        lastPauseStart = Date()
        elapsedTimeAtLastPause = elapsedTime
        state = .paused
        saveState()
    }
    
    private func resumeTimer() {
        if let pauseStart = lastPauseStart {
            totalPauseDuration += Date().timeIntervalSince(pauseStart)
        }
        lastPauseStart = nil
        state = .running
        startTimer()
        saveState()
    }
    
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
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
    }
    
    private func updateElapsedTime() {
        guard let start = startTimestamp else { return }
        
        if state == .paused {
            elapsedTime = elapsedTimeAtLastPause
        } else {
            let currentTime = Date()
            let totalElapsed = currentTime.timeIntervalSince(start)
            var pauseDuration = totalPauseDuration
            
            if let pauseStart = lastPauseStart {
                pauseDuration += currentTime.timeIntervalSince(pauseStart)
            }
            
            elapsedTime = totalElapsed - pauseDuration
        }
    }
    
    // MARK: - State Persistence
    private func saveState() {
        let timerData = TimerData(
            startTimestamp: startTimestamp ?? Date(),
            totalPauseDuration: totalPauseDuration,
            lastPauseStart: lastPauseStart,
            state: state,
            elapsedTimeAtLastPause: elapsedTimeAtLastPause
        )
        
        if let encoded = try? JSONEncoder().encode(timerData) {
            UserDefaults.standard.set(encoded, forKey: "MyTimeProTimerData")
        }
    }
    
    private func loadSavedState() {
        guard let data = UserDefaults.standard.data(forKey: "MyTimeProTimerData"),
              let timerData = try? JSONDecoder().decode(TimerData.self, from: data) else {
            return
        }
        
        state = timerData.state
        startTimestamp = timerData.startTimestamp
        totalPauseDuration = timerData.totalPauseDuration
        lastPauseStart = timerData.lastPauseStart
        elapsedTimeAtLastPause = timerData.elapsedTimeAtLastPause
        
        if state == .running {
            updateElapsedTime()
            startTimer()
        } else if state == .paused {
            elapsedTime = elapsedTimeAtLastPause
        }
    }
    
    // MARK: - Cleanup
    deinit {
        timer?.invalidate()
    }
}