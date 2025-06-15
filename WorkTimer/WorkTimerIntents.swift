import AppIntents
import SwiftUI // For @MainActor and potentially other UI related types if ever needed by intents.
// TimerManager will be accessed via its singleton.

// MARK: - Toggle Timer Intent
struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Work Timer"
    static var description: IntentDescription = IntentDescription("Starts, pauses, or resumes the current work timer.")
    static var openAppWhenRun: Bool = true // Ensure app handles the action

    @MainActor // TimerManager.shared and its properties are marked @MainActor
    func perform() async throws -> some IntentResult {
        let timerManager = WorkTimerManager.shared

        // Temporary modelContext setup removed.
        // openAppWhenRun = true should ensure TimerManager.shared.modelContext is valid
        // as it's configured in the main app's lifecycle.

        timerManager.toggleTimer()
        print("ToggleTimerIntent performed in-app. Current state: \(timerManager.state)")
        return .result()
    }
}

// MARK: - End Day Intent
struct EndDayIntent: AppIntent {
    static var title: LocalizedStringResource = "End Work Day"
    static var description: IntentDescription = IntentDescription("Ends the current work day and saves the session.")
    static var openAppWhenRun: Bool = true // Ensure app handles the action

    @MainActor // TimerManager.shared and its properties are marked @MainActor
    func perform() async throws -> some IntentResult {
        let timerManager = WorkTimerManager.shared

        // Temporary modelContext setup removed.
        // openAppWhenRun = true should ensure TimerManager.shared.modelContext is valid.

        if timerManager.state == .running || timerManager.state == .paused {
            timerManager.endDay()
            print("EndDayIntent performed in-app. Current state: \(timerManager.state)")
        } else {
            print("EndDayIntent: No active timer to end.")
            // Optionally, provide a custom result to indicate why it didn't run.
            // For example: return .result(value: "No active timer to end.")
            // However, the intent definition would need to support a value.
        }
        return .result()
    }
}
