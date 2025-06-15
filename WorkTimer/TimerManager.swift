import Foundation
import Observation
import SwiftData
import SwiftUI
import ActivityKit

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
@Observable
class WorkTimerManager {
    // MARK: - Singleton
    static let shared = WorkTimerManager()
    
    // MARK: - Properties
    private(set) var state: TimerState = .notStarted
    private(set) var elapsedTime: TimeInterval = 0
    var showEndDayAlert = false
    var pauseTime: Date?
    private(set) var currentWorkDay: WorkDay?
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var modelContext: ModelContext!
    @MainActor private var currentActivity: Activity<WorkTimerActivityAttributes>? = nil
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
    private init() {} // For shared instance

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSavedState()
    }
    
    // MARK: - Public Methods
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Ensure modelContext is set before loading state that might use it
        // (e.g., if loadSavedState or its side effects were to interact with WorkDay entities)
        loadSavedState()
    }

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

        // Start Live Activity
        if #available(iOS 16.1, *) {
            let attributes = WorkTimerActivityAttributes(timerName: "Work Session")
            let initialContentState = WorkTimerActivityAttributes.ContentState(
                elapsedTime: 0, // elapsedTime is 0 when starting a new day
                timerState: .running,
                currentAccentColorName: UserSettings.shared.accentColorName
            )
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    contentState: initialContentState,
                    pushType: nil // No push notifications for updates
                )
                self.currentActivity = activity
                print("Live Activity requested with ID: \(activity.id)")
            } catch {
                print("Error requesting Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    func pauseTimer() {
        guard state == .running else { return }
        
        lastPauseStart = Date()
        state = .paused
        timer?.invalidate()
        timer = nil
        
        saveState()

        // Update Live Activity
        if #available(iOS 16.1, *) {
            let contentState = WorkTimerActivityAttributes.ContentState(
                elapsedTime: self.elapsedTime,
                timerState: .paused,
                currentAccentColorName: UserSettings.shared.accentColorName
            )
            Task {
                await self.currentActivity?.update(using: contentState)
                print("Live Activity updated to Paused state.")
            }
        }
    }
    
    func resumeTimer() {
        guard state == .paused, let pauseStart = lastPauseStart else { return }
        
        let now = Date()
        totalPauseDuration += now.timeIntervalSince(pauseStart)
        lastPauseStart = nil
        state = .running
        
        startTimer()
        saveState()

        // Update Live Activity
        if #available(iOS 16.1, *) {
            // If activity is nil (e.g. app was terminated), try to start a new one.
            // This logic might need refinement based on how app handles existing activities on launch.
            if self.currentActivity == nil {
                 let attributes = WorkTimerActivityAttributes(timerName: "Work Session")
                 let initialContentState = WorkTimerActivityAttributes.ContentState(
                     elapsedTime: self.elapsedTime,
                     timerState: .running,
                     currentAccentColorName: UserSettings.shared.accentColorName
                 )
                 do {
                     let activity = try Activity.request(
                         attributes: attributes,
                         contentState: initialContentState,
                         pushType: nil
                     )
                     self.currentActivity = activity
                     print("Live Activity (re)started on resume: \(activity.id)")
                 } catch {
                     print("Error (re)starting Live Activity on resume: \(error.localizedDescription)")
                 }
            } else {
                let contentState = WorkTimerActivityAttributes.ContentState(
                    elapsedTime: self.elapsedTime,
                    timerState: .running,
                    currentAccentColorName: UserSettings.shared.accentColorName
                )
                Task {
                    await self.currentActivity?.update(using: contentState)
                    print("Live Activity updated to Running state on resume.")
                }
            }
        }
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

        // End Live Activity
        if #available(iOS 16.1, *) {
            let finalContentState = WorkTimerActivityAttributes.ContentState(
                elapsedTime: self.elapsedTime, // Final elapsed time
                timerState: .finished,
                currentAccentColorName: UserSettings.shared.accentColorName
            )
            Task {
                await self.currentActivity?.end(using: finalContentState, dismissalPolicy: .default)
                self.currentActivity = nil
                print("Live Activity ended on endDay.")
            }
        }
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

        // End Live Activity immediately
        if #available(iOS 16.1, *) {
            Task {
                let contentState = WorkTimerActivityAttributes.ContentState(
                    elapsedTime: 0,
                    timerState: .notStarted,
                    currentAccentColorName: UserSettings.shared.accentColorName
                )
                await self.currentActivity?.end(using: contentState, dismissalPolicy: .immediate)
                self.currentActivity = nil
                print("Live Activity ended on resetTimer.")
            }
        }
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

        // Update Live Activity periodically
        if #available(iOS 16.1, *) {
            if self.state == .running && Int(self.elapsedTime) % 10 == 0 { // Update every 10 seconds
                let contentState = WorkTimerActivityAttributes.ContentState(
                    elapsedTime: self.elapsedTime,
                    timerState: self.state, // Should be .running here
                    currentAccentColorName: UserSettings.shared.accentColorName
                )
                Task {
                    await self.currentActivity?.update(using: contentState)
                    // print("Live Activity updated at \(Int(self.elapsedTime))s.") // Can be noisy
                }
            }
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
            UserDefaults(suiteName: SharedConstants.appGroupID)?.set(encoded, forKey: "timerState")
        }
    }
    
    private func loadSavedState() {
        guard let userDefaults = UserDefaults(suiteName: SharedConstants.appGroupID),
              let data = userDefaults.data(forKey: "timerState"),
              let timerData = try? JSONDecoder().decode(TimerData.self, from: data) else {
            // Fallback to standard UserDefaults if app group is nil or data not found,
            // or handle as a fresh start. For now, just return.
            // Consider logging an error here if userDefaults is nil.
            if UserDefaults(suiteName: SharedConstants.appGroupID) == nil {
                print("Error: App Group UserDefaults suite could not be initialized in TimerManager.loadSavedState().")
            }
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
