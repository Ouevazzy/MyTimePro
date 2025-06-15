import WidgetKit
import SwiftUI
import ActivityKit

struct WorkTimerLiveActivityView: View {
    let context: ActivityViewContext<WorkTimerActivityAttributes>

    // Access UserSettings to resolve accent color name to actual Color
    // This assumes UserSettings.swift is also part of the widget extension target.
    // If UserSettings cannot be directly used, the accentColor itself would need to be passed
    // in ContentState, which is less ideal as Color isn't directly Codable.
    // Passing the name and resolving it here is a common pattern.
    private var accentColor: Color {
        UserSettings.AccentColor(rawValue: context.state.currentAccentColorName)?.color ?? UserSettings.AccentColor.defaultBlue.color
    }

    var body: some View {
        // This is the root view for the Live Activity, primarily for the lock screen.
        // Dynamic Island presentations will be defined in the ActivityConfiguration.
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: timerIconName)
                    .foregroundColor(accentColor)
                Text(context.attributes.timerName)
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
                Text(timerStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Divider().background(Color.white.opacity(0.3))

            HStack {
                Label(formattedTime(context.state.elapsedTime), systemImage: "timer")
                    .font(Font.system(.title3, design: .rounded).monospacedDigit())
                Spacer()
                // Placeholder for potential quick actions on lock screen if desired later
            }
        }
        .padding(15)
        .activityBackgroundTint(accentColor.opacity(0.2)) // Use dynamic accent color
        .activitySystemActionForegroundColor(Color.primary) // Adapts to light/dark text on tinted bg
    }

    // Helper to format time
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        let seconds = Int(roundedInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var timerStatusText: String {
        switch context.state.timerState {
        case .notStarted: return "Not Started" // Should ideally not happen for an active LA
        case .running: return "Running"
        case .paused: return "Paused"
        case .finished: return "Finished" // LA should typically end before this
        }
    }

    private var timerIconName: String {
        switch context.state.timerState {
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        default: return "timer"
        }
    }
}

// It's good practice to also provide a preview for the Live Activity view.
// This requires iOS 16.1+ for ActivityAttributes.
@available(iOS 16.1, *)
struct WorkTimerLiveActivityView_Previews: PreviewProvider {
    static let attributes = WorkTimerActivityAttributes(timerName: "Work Session")
    static let contentStateRunning = WorkTimerActivityAttributes.ContentState(
        elapsedTime: 3665, // 1h 1min 5s
        timerState: .running,
        currentAccentColorName: UserSettings.AccentColor.defaultBlue.rawValue
    )
    static let contentStatePaused = WorkTimerActivityAttributes.ContentState(
        elapsedTime: 1502, // 25min 2s
        timerState: .paused,
        currentAccentColorName: UserSettings.AccentColor.orange.rawValue
    )

    static var previews: some View {
        Group {
            ActivityPreview(attributes: attributes, state: contentStateRunning) {
                WorkTimerLiveActivityView(context: $0)
            }
            .previewDisplayName("Running State (Lock Screen)")

            ActivityPreview(attributes: attributes, state: contentStatePaused) {
                WorkTimerLiveActivityView(context: $0)
            }
            .previewDisplayName("Paused State (Lock Screen)")
        }
        // Simulate the widget medium size to get a sense of the lock screen appearance
        .widgetPreviewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
