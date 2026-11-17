import SwiftUI

/// Aperçu passif : toucher une date conserve la grille et actualise ce contenu.
struct CalendarSelectionPreview: View {
    let date: Date
    let entries: [WorkDay]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var totalHours: Double {
        entries.reduce(0) { $0 + $1.totalHours }
    }

    private var balanceSeconds: Int {
        entries.reduce(0) { $0 + $1.overtimeSeconds }
    }

    private var entryTypes: [WorkDayType] {
        WorkDayType.allCases.filter { type in entries.contains { $0.type == type } }
    }

    private var formattedBalance: String {
        let value = WorkTimeCalculations.formattedSecondsRounded(balanceSeconds)
        return balanceSeconds > 0 ? "+\(value)" : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    dateLabel
                    entryCount
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    dateLabel
                    Spacer(minLength: DS.Spacing.sm)
                    entryCount
                }
            }

            if entries.isEmpty {
                Text("calendar.day.noEntry".localized)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .accessibilityIdentifier("calendar.preview.empty")
            } else {
                entryDescription

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            hoursLabel
                            balanceLabel
                        }
                    } else {
                        HStack(spacing: DS.Spacing.lg) {
                            hoursLabel
                            balanceLabel
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .dsContentSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.selection-preview")
    }

    private var dateLabel: some View {
        Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)))
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("calendar.preview.date")
    }

    @ViewBuilder
    private var entryCount: some View {
        if entries.count > 1 {
            Text("workDays.entries.count".localized(entries.count))
                .font(.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .fixedSize()
        }
    }

    private var entryDescription: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            if let entry = entries.first, entries.count == 1 {
                Image(systemName: entry.type.icon)
                    .foregroundStyle(entry.type.color)
                    .accessibilityHidden(true)
            }

            Text(entryTypes.map(\.localizedName).joined(separator: " · "))
                .fixedSize(horizontal: false, vertical: true)

            if entries.count == 1,
               let entry = entries.first,
               entry.type.isWorkDay,
               let start = entry.startTime,
               let end = entry.endTime {
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.caption)
        .foregroundStyle(DS.Colors.secondaryText)
    }

    private var hoursLabel: some View {
        Label(WorkTimeCalculations.formattedHoursRounded(totalHours), systemImage: "clock")
            .accessibilityLabel("calendar.preview.hours".localized(WorkTimeCalculations.formattedHoursRounded(totalHours)))
    }

    private var balanceLabel: some View {
        Text("calendar.preview.balance".localized(formattedBalance))
            .foregroundStyle(DS.Colors.balance(Double(balanceSeconds)))
            .accessibilityIdentifier("calendar.preview.balance")
    }
}
