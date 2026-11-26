//
//  TimerWidget.swift
//  WorkTimerWidget
//
//  Widget « Chrono » (boutons pointer / pause / départ) et commande du
//  Centre de contrôle. Les actions sont dans TimerIntents.swift.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget « Chrono »

struct TimerWidgetEntry: TimelineEntry {
    let date: Date
    let state: SharedTimerState
}

struct TimerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerWidgetEntry {
        TimerWidgetEntry(date: .now, state: SharedTimerState(startDate: .now.addingTimeInterval(-3 * 3600 - 25 * 60)))
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : TimerWidgetEntry(date: .now, state: .read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        // L'app recharge le widget à chaque changement d'état ; le compteur avance seul.
        completion(Timeline(entries: [TimerWidgetEntry(date: .now, state: .read())], policy: .never))
    }
}

struct TimerWidgetView: View {
    let entry: TimerWidgetEntry

    private var state: SharedTimerState { entry.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
                Text("timer.title")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            Spacer(minLength: 0)

            elapsed
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(statusKey)
                .font(.caption2)
                .foregroundStyle(.secondary)

            buttons
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder private var elapsed: some View {
        if let countingStart = state.countingStart {
            Text(countingStart, style: .timer)
        } else if state.isActive {
            // Même format que le compteur en cours : m:ss sous une heure, h:mm:ss au-delà.
            let worked = state.workedSeconds(at: entry.date)
            Text(Duration.seconds(worked),
                 format: .time(pattern: worked < 3600 ? .minuteSecond : .hourMinuteSecond))
        } else {
            Text(Duration.seconds(0), format: .time(pattern: .hourMinute))
                .foregroundStyle(.secondary)
        }
    }

    private var statusKey: LocalizedStringKey {
        if !state.isActive { return "timerWidget.idle" }
        return state.isPaused ? "timer.paused" : "timer.running"
    }

    @ViewBuilder private var buttons: some View {
        if !state.isActive {
            Button(intent: StartTimerIntent()) {
                Label("timer.clockIn", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)
        } else {
            HStack(spacing: 6) {
                if state.isPaused {
                    Button(intent: ResumeTimerIntent()) {
                        Image(systemName: "play.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.blue)
                    .accessibilityLabel(Text("timer.resume"))
                } else {
                    Button(intent: PauseTimerIntent()) {
                        Image(systemName: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.orange)
                    .accessibilityLabel(Text("timer.pause"))
                }
                Button(intent: StopTimerIntent()) {
                    Image(systemName: "stop.fill").frame(maxWidth: .infinity)
                }
                .tint(.red)
                .accessibilityLabel(Text("timer.clockOut"))
            }
        }
    }
}

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedTimerState.widgetKind, provider: TimerWidgetProvider()) { entry in
            TimerWidgetView(entry: entry)
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .font(.caption)
        }
        .configurationDisplayName("timer.title")
        .description("timerWidget.description")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Commande du Centre de contrôle et du bouton Action

struct TimerControl: ControlWidget {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { SharedTimerState.read().isActive }
    }

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SharedTimerState.controlKind, provider: Provider()) { isActive in
            ControlWidgetToggle("timer.title", isOn: isActive, action: SetTimerRunningIntent()) { isOn in
                Label(isOn ? "timer.running" : "timer.clockIn",
                      systemImage: isOn ? "stop.circle.fill" : "play.circle.fill")
            }
            .tint(.blue)
        }
        .displayName("timer.title")
        .description("timerControl.description")
    }
}

#Preview(as: .systemSmall) {
    TimerWidget()
} timeline: {
    TimerWidgetEntry(date: .now, state: SharedTimerState())
    TimerWidgetEntry(date: .now, state: SharedTimerState(startDate: .now.addingTimeInterval(-5000)))
    TimerWidgetEntry(date: .now, state: SharedTimerState(startDate: .now.addingTimeInterval(-5000), pauseStartedAt: .now))
}
