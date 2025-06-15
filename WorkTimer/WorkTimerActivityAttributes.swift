import ActivityKit
import SwiftUI // For TimerState if it's used and has SwiftUI elements, or if Color/Font etc. are part of attributes/state

// Assuming TimerState from TimerManager.swift (or a shared file) is accessible.
// If not, it might need to be defined/redefined here or in a shared location.
// For this structure, TimerState from the main app target is assumed.

struct WorkTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic values that update frequently
        var elapsedTime: TimeInterval // Calculated based on various time stamps from TimerManager
        var timerState: TimerState    // e.g., .running, .paused
        var currentAccentColorName: String // To ensure the LA can use the theme color
    }

    // Static values, set once when activity starts
    var timerName: String // e.g., "Work Session"
    // No need for raw start/pause timestamps here, they are used to compute `elapsedTime`
    // which is then passed in `ContentState`.
}
