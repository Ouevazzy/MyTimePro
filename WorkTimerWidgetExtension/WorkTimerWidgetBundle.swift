import WidgetKit
import SwiftUI

@main
struct WorkTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkTimerStatusWidget() // Existing widget

        if #available(iOS 16.1, *) { // Check for iOS version supporting Live Activities
            WorkTimerLiveActivity() // New Live Activity
        }
    }
}

// Define the Live Activity Widget struct
@available(iOS 16.1, *) // Ensure this is only compiled for supporting OS versions
struct WorkTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkTimerActivityAttributes.self) { context in
            // Lock screen UI: Reuses the main Live Activity view.
            // Ensure WorkTimerLiveActivityView.swift is part of the widget extension target.
            WorkTimerLiveActivityView(context: context)
                .padding() // Add some padding around the lock screen view
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI: Reuses the main Live Activity view for all expanded regions for simplicity.
                // More tailored UIs can be designed for each region if needed.
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.timerState == .paused ? "Paused" : "Running", systemImage: context.state.timerState == .paused ? "pause.fill" : "play.fill")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label(formattedTime(context.state.elapsedTime), systemImage: "timer")
                        .font(.caption)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                     // Empty for now, or use a very minimal display like just timer name
                    Text(context.attributes.timerName)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // This is a good place for primary information or actions if needed.
                    // For now, keep it simple.
                    Text("Elapsed: \(formattedTime(context.state.elapsedTime))")
                        .font(.headline)
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: context.state.timerState == .paused ? "pause.fill" : "play.fill")
                    .foregroundColor(UserSettings.AccentColor(rawValue: context.state.currentAccentColorName)?.color ?? .blue)
            } compactTrailing: {
                Text(formattedTimeCompact(context.state.elapsedTime))
                    .monospacedDigit()
                    .font(.caption)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(UserSettings.AccentColor(rawValue: context.state.currentAccentColorName)?.color ?? .blue)
            }
            .widgetURL(URL(string: "worktimerapp://home")) // URL to open app
            .keylineTint(UserSettings.AccentColor(rawValue: context.state.currentAccentColorName)?.color ?? .blue) // Tint for DI outline
        }
    }

    // Helper function to format time for compact display (can be shared)
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        // Omitting seconds for expanded view for brevity, can be added if desired
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%02dm", minutes)
        }
    }

    private func formattedTimeCompact(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        if hours > 0 {
            return String(format: "%dh%02d", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}
