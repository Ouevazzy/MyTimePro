import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct TimerStatusEntry: TimelineEntry {
    let date: Date
    let statusText: String
    let elapsedTimeText: String
    let timerState: TimerState // To determine button text and actions later
    let isEndDayButtonVisible: Bool
    let accentColor: Color // To pass theme color
}

// MARK: - Widget View
struct WorkTimerWidgetEntryView : View {
    var entry: TimerStatusEntry
    @Environment(\.widgetFamily) var family

    // Placeholder AppIntents removed, actual intents will be used.

    var body: some View {
        if family == .systemMedium {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STATUT")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.statusText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(entry.accentColor)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 0)

                    Text("TEMPS ÉCOULÉ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.elapsedTimeText)
                        .font(Font.system(.title2, design: .rounded).monospacedDigit())
                        .fontWeight(.medium)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    Button(intent: ToggleTimerIntent()) { // Use actual ToggleTimerIntent
                        Label(toggleButtonText, systemImage: toggleButtonIcon)
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(entry.accentColor)

                    if entry.isEndDayButtonVisible {
                        Button(intent: EndDayIntent()) { // Use actual EndDayIntent
                            Label("Terminer", systemImage: "stop.circle.fill")
                                .font(.callout)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        // Placeholder to maintain layout if button is not visible
                        // Or adjust layout dynamically if preferred
                        Button {} label: {
                            Label("Terminer", systemImage: "stop.circle.fill")
                                .font(.callout)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .hidden() // Keeps space
                    }
                }
                .frame(width: 130) // Fixed width for buttons column
            }
            .padding()
        } else {
            // Placeholder for other families if needed
            Text("Unsupported widget family.")
        }
    }

    private var toggleButtonText: String {
        switch entry.timerState {
        case .notStarted, .finished: return "Démarrer"
        case .running: return "Pause"
        case .paused: return "Reprendre"
        }
    }

    private var toggleButtonIcon: String {
        switch entry.timerState {
        case .notStarted, .finished: return "play.circle.fill"
        case .running: return "pause.circle.fill"
        case .paused: return "play.circle.fill" // Or a resume icon like "arrow.clockwise.circle.fill"
        }
    }
}

// MARK: - Timeline Provider
struct TimerStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerStatusEntry {
        TimerStatusEntry(date: Date(),
                           statusText: "En Pause",
                           elapsedTimeText: "00:45:12",
                           timerState: .paused,
                           isEndDayButtonVisible: true,
                           accentColor: UserSettings.shared.accentColor)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerStatusEntry) -> ()) {
        let timerManager = WorkTimerManager.shared
        let entry = createEntry(from: timerManager, date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let timerManager = WorkTimerManager.shared
        let currentDate = Date()
        let entry = createEntry(from: timerManager, date: currentDate)

        // Refresh policy:
        // If timer is running, refresh every minute.
        // Otherwise, refresh less frequently (e.g., every 15-30 minutes or on significant time change).
        // For now, a simple 1-minute refresh if running, else 1 hour.
        let refreshDate: Date
        if timerManager.state == .running {
            refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        } else {
            refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        }

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry(from timerManager: WorkTimerManager, date: Date) -> TimerStatusEntry {
        let status: String
        switch timerManager.state {
        case .notStarted: status = "Non Démarré"
        case .running: status = "En Cours"
        case .paused: status = "En Pause"
        case .finished: status = "Terminé"
        }

        let elapsedTime = timerManager.elapsedTime
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        let elapsedTimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

        let isEndDayVisible = timerManager.state == .running || timerManager.state == .paused

        return TimerStatusEntry(date: date,
                                  statusText: status,
                                  elapsedTimeText: elapsedTimeString,
                                  timerState: timerManager.state,
                                  isEndDayButtonVisible: isEndDayVisible,
                                  accentColor: UserSettings.shared.accentColor)
    }
}

// MARK: - Widget Definition
struct WorkTimerStatusWidget: Widget {
    let kind: String = "WorkTimerStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerStatusProvider()) { entry in
            WorkTimerWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "worktimerapp://home")) // Example URL
        }
        .configurationDisplayName("Statut WorkTimer")
        .description("Affichez l'état actuel de votre minuteur et accédez aux actions rapides.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    WorkTimerStatusWidget()
} timeline: {
    TimerStatusEntry(date: Date(), statusText: "En Cours", elapsedTimeText: "01:15:30", timerState: .running, isEndDayButtonVisible: true, accentColor: .blue)
    TimerStatusEntry(date: Date(), statusText: "En Pause", elapsedTimeText: "02:30:05", timerState: .paused, isEndDayButtonVisible: true, accentColor: .orange)
    TimerStatusEntry(date: Date(), statusText: "Non Démarré", elapsedTimeText: "00:00:00", timerState: .notStarted, isEndDayButtonVisible: false, accentColor: .green)
}

// Required for AppIntent placeholders to compile.
// Placeholder/stub AppIntent protocols removed as they are no longer needed here.
// Actual AppIntents are defined in WorkTimerIntents.swift and imported via AppIntents framework.
```
