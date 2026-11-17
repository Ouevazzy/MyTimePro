import WidgetKit
import SwiftUI

// MARK: - Données partagées

/// Doit correspondre à WidgetSnapshotService.appGroupID côté app.
private let appGroupID = "group.jordan-payez.MyTimePro"

struct WorkTimerEntry: TimelineEntry {
    let date: Date
    let weeklyHours: Double
    let overtimeSeconds: Int
    let vacationBalance: Double
    let isPlaceholder: Bool

    static let placeholder = WorkTimerEntry(
        date: .now,
        weeklyHours: 32.5,
        overtimeSeconds: 5_400,
        vacationBalance: 12.5,
        isPlaceholder: true
    )

    static func fromSharedDefaults() -> WorkTimerEntry {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              defaults.object(forKey: "widget.updatedAt") != nil else {
            return .placeholder
        }
        return WorkTimerEntry(
            date: .now,
            weeklyHours: defaults.double(forKey: "widget.weeklyHours"),
            overtimeSeconds: defaults.integer(forKey: "widget.overtimeSeconds"),
            vacationBalance: defaults.double(forKey: "widget.vacationBalance"),
            isPlaceholder: false
        )
    }
}

// MARK: - Provider

struct WorkTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkTimerEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WorkTimerEntry) -> Void) {
        completion(.fromSharedDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkTimerEntry>) -> Void) {
        let entry = WorkTimerEntry.fromSharedDefaults()
        // L'app force un reload à chaque modification de données ;
        // le refresh horaire n'est qu'un filet de sécurité.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Formatage

private func formatHours(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return m == 0 ? "\(h)h" : String(format: "%dh%02d", h, m)
}

private func formatOvertime(_ seconds: Int) -> String {
    let sign = seconds < 0 ? "-" : "+"
    let abs = Swift.abs(seconds)
    let h = abs / 3600
    let m = (abs % 3600) / 60
    return m == 0 ? "\(sign)\(h)h" : String(format: "%@%dh%02d", sign, h, m)
}

// MARK: - Vues

struct WorkTimerWidgetEntryView: View {
    var entry: WorkTimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // Écran verrouillé — cercle : heures de la semaine
    private var circularView: some View {
        VStack(spacing: 0) {
            Image(systemName: "briefcase.fill")
                .font(.caption2)
            Text(formatHours(entry.weeklyHours))
                .font(.headline)
                .minimumScaleFactor(0.6)
        }
        .containerBackground(.clear, for: .widget)
    }

    // Écran verrouillé — rectangle : semaine + heures supp
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "briefcase.fill")
                Text(formatHours(entry.weeklyHours))
                    .fontWeight(.semibold)
            }
            .font(.headline)

            Text(formatOvertime(entry.overtimeSeconds))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.clear, for: .widget)
    }

    // Écran d'accueil — petit : heures de la semaine en héros
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundStyle(.blue)
                Spacer()
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatHours(entry.weeklyHours))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)

            Text("widget.thisWeek")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatOvertime(entry.overtimeSeconds))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(entry.overtimeSeconds >= 0 ? .green : .red)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Écran d'accueil — moyen : semaine + supp + congés
    private var mediumView: some View {
        HStack(spacing: 16) {
            statColumn(
                icon: "briefcase.fill",
                color: .blue,
                value: formatHours(entry.weeklyHours),
                label: String(localized: "widget.thisWeek")
            )
            statColumn(
                icon: entry.overtimeSeconds >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                color: entry.overtimeSeconds >= 0 ? .green : .red,
                value: formatOvertime(entry.overtimeSeconds),
                label: String(localized: "widget.overtime")
            )
            statColumn(
                icon: "sun.max.fill",
                color: .orange,
                value: String(format: "%.1f j", entry.vacationBalance),
                label: String(localized: "widget.vacationRemaining")
            )
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func statColumn(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget

struct WorkTimerWidget: Widget {
    let kind = "WorkTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkTimerProvider()) { entry in
            WorkTimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct WorkTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkTimerWidget()
    }
}

#Preview(as: .systemSmall) {
    WorkTimerWidget()
} timeline: {
    WorkTimerEntry.placeholder
}
