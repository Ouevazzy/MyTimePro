//
//  CalendarDayViews.swift
//  WorkTimer
//
//  Cellules, badges, timeline et sélecteur de date du calendrier.
//

import SwiftUI
import SwiftData

// MARK: - Sous-vues améliorées

/// Cellule de calendrier améliorée avec design Liquid Glass
/// Étiquette capsule du type de journée, façon événement Calendrier Apple.
/// Contraste renforcé + fallback opaque si reduceTransparency.
struct DayTypeBadge: View {
    let type: WorkDayType

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(type.localizedName)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(reduceTransparency ? Color.white : type.color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            .background(
                type.color.opacity(reduceTransparency ? 1.0 : (colorScheme == .dark ? 0.30 : 0.20)),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

struct ImprovedCalendarCell: View {
    let date: Date
    let workDays: [WorkDay]
    let isSelected: Bool
    let isToday: Bool
    var isWeekend: Bool = false
    var eventDisplayMode: CalendarEventDisplayMode = .compact
    /// Jour férié du canton, pas encore saisi.
    var isHoliday: Bool = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar = CalendarGridLayout.displayCalendar

    private var workDay: WorkDay? { workDays.first }
    private var entryCount: Int { workDays.count }
    private var totalHours: Double { workDays.reduce(0) { $0 + $1.totalHours } }

    private var typeRepresentatives: [WorkDay] {
        var seenTypes = Set<String>()
        return workDays.filter { seenTypes.insert($0.typeRawValue).inserted }
    }

    var body: some View {
        VStack(spacing: 3) {
            // Numéro du jour dans un cercle (visible uniquement si sélectionné/aujourd'hui)
            ZStack {
                if isSelected {
                    // Façon Calendrier Apple : aujourd'hui = cercle accent,
                    // autre jour = cercle plein contrasté (noir en clair, blanc en sombre).
                    Circle()
                        .fill(isToday ? Color.blue : Color.primary)
                        .transition(.scale.combined(with: .opacity))
                } else if isToday {
                    Circle()
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12))
                }

                Text(String(calendar.component(.day, from: date)))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday || isSelected ? .semibold : .regular)
                    .monospacedDigit()
                    .foregroundStyle(textColor)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .frame(width: 34, height: 34)

            // Calendrier propose une présentation compacte ou détaillée des événements.
            if let workDay {
                switch eventDisplayMode {
                case .compact:
                    let layout = dynamicTypeSize >= .xxLarge
                        ? AnyLayout(VStackLayout(spacing: 1))
                        : AnyLayout(HStackLayout(spacing: 3))
                    layout {
                        HStack(spacing: 3) {
                            ForEach(typeRepresentatives.prefix(2)) { entry in
                                Image(systemName: entry.type.icon)
                                    .foregroundStyle(entry.type.color)
                            }
                        }
                        if entryCount > min(typeRepresentatives.count, 2) {
                            Text("+\(entryCount - min(typeRepresentatives.count, 2))")
                                .foregroundStyle(DS.Colors.secondaryText)
                                .fixedSize()
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityHidden(true)
                case .stack:
                    HStack(spacing: 2) {
                        DayTypeBadge(type: workDay.type)
                        if entryCount > 1 {
                            Text("+\(entryCount - 1)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                    .padding(.horizontal, 2)
                case .details:
                    VStack(spacing: 1) {
                        DayTypeBadge(type: workDay.type)
                        if totalHours > 0 {
                            Text(WorkTimeCalculations.formattedHoursTruncated(totalHours))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(DS.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            } else if isHoliday {
                // Étoile vide : férié non saisi (pleine une fois la journée ajoutée).
                Image(systemName: "star")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .frame(height: eventDisplayMode == .compact ? 14 : 17)
                    .accessibilityHidden(true)
            } else {
                Color.clear
                    .frame(height: eventDisplayMode == .compact ? 14 : 17)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .frame(minHeight: eventDisplayMode == .compact ? 56 : eventDisplayMode == .stack ? 63 : 72, alignment: .top)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // Couleur du texte basée sur l'état
    private var textColor: Color {
        if isSelected {
            // Sur cercle accent → blanc ; sur cercle Color.primary → couleur inversée
            return isToday ? .white : Color(.systemBackground)
        } else if isToday {
            return .blue
        }
        return isWeekend ? .secondary : .primary
    }
}

/// Ligne horaire inspirée de la présentation Jour de Calendrier Apple.
struct WorkDayTimelineView: View {
    let date: Date
    let workDays: [WorkDay]
    let calendar: Calendar
    let onAdd: () -> Void
    let onEdit: (WorkDay) -> Void
    let onDelete: (WorkDay) -> Void

    private let hourHeight: CGFloat = 68
    private let hourLabelWidth: CGFloat = 54
    private let timelineTopInset: CGFloat = 8

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    daySummary

                    ZStack(alignment: .topLeading) {
                        timelineGrid

                        ForEach(timedWorkDays) { workDay in
                            timelineEvent(workDay)
                        }

                        if calendar.isDateInToday(date) {
                            currentTimeIndicator
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .accessibilityIdentifier("calendar.timeline")
                }
            }
            .scrollIndicators(.visible)
            .task(id: CalendarGridLayout.dateIdentity(for: date, calendar: calendar)) {
                await Task.yield()
                proxy.scrollTo(initialScrollHour, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private var daySummary: some View {
        if workDays.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("calendar.day.noEntry".localized)
                        .font(.subheadline.weight(.semibold))
                    Text("calendar.day.noEntry.detail".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("action.add".localized, action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial)
        } else {
            VStack(spacing: DS.Spacing.xs) {
                if workDays.count > 1 {
                    dailyAggregateSummary
                }

                ForEach(nonTimedWorkDays) { workDay in
                    nonTimedSummary(workDay)
                }
            }
        }
    }

    private var dailyAggregateSummary: some View {
        let totalHours = workDays.reduce(0.0) { $0 + $1.totalHours }
        let overtimeSeconds = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        let formattedBalance = WorkTimeCalculations.formattedSecondsRounded(overtimeSeconds)

        return HStack(spacing: DS.Spacing.md) {
            Label("workDays.entries.count".localized(workDays.count), systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.semibold))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(WorkTimeCalculations.formattedHoursRounded(totalHours))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(overtimeSeconds > 0 ? "+\(formattedBalance)" : formattedBalance)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.balance(Double(overtimeSeconds)))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial)
    }

    private func nonTimedSummary(_ workDay: WorkDay) -> some View {
        Button {
            onEdit(workDay)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: workDay.type.icon)
                    .foregroundStyle(workDay.type.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workDay.type.localizedName)
                        .font(.headline)
                    if let note = workDay.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(workDay.type.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(workDay)
            } label: {
                Label("action.delete".localized, systemImage: "trash")
            }
        }
    }

    private var timedWorkDays: [WorkDay] {
        workDays
            .filter { $0.type.isWorkDay && $0.startTime != nil && $0.endTime != nil }
            .sorted { ($0.startTime ?? $0.date) < ($1.startTime ?? $1.date) }
    }

    private var nonTimedWorkDays: [WorkDay] {
        workDays.filter {
            !$0.type.isWorkDay || $0.startTime == nil || $0.endTime == nil
        }
    }

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d:00", hour))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: hourLabelWidth, alignment: .trailing)
                            .offset(y: -7)

                        Rectangle()
                            .fill(Color.secondary.opacity(0.22))
                            .frame(height: 0.5)
                    }
                    .offset(y: timelineTopInset)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .padding(.trailing)
    }

    private func timelineEvent(_ workDay: WorkDay) -> some View {
        Button {
            onEdit(workDay)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(workDay.type.localizedName)
                    .font(.headline)
                    .lineLimit(1)
                Text(timeRange(for: workDay))
                    .font(.caption.monospacedDigit())
                HStack(spacing: 8) {
                    Text(workDay.formattedTotalHours)
                    if workDay.breakDuration > 0 {
                        Text("calendar.timeline.break".localized(formatDuration(workDay.breakDuration)))
                    }
                }
                .font(.caption2)
                .lineLimit(1)
            }
            .foregroundStyle(workDay.type.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                workDay.type.color.opacity(0.20),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(workDay.type.color)
                    .frame(width: 5)
                    .padding(.vertical, 7)
            }
        }
        .buttonStyle(.plain)
        .frame(height: eventHeight(for: workDay))
        .padding(.leading, hourLabelWidth + 14)
        .padding(.trailing, 10)
        .offset(y: timelineTopInset + eventOffset(for: workDay))
        .contextMenu {
            Button {
                onEdit(workDay)
            } label: {
                Label("action.edit".localized, systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(workDay)
            } label: {
                Label("action.delete".localized, systemImage: "trash")
            }
        }
        .accessibilityIdentifier("calendar.timeline-event")
    }

    private var currentTimeIndicator: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .padding(.leading, hourLabelWidth + 7)
        .padding(.trailing, 8)
        .offset(y: timelineTopInset + minutesSinceStartOfDay(Date()) / 60 * hourHeight)
        .accessibilityHidden(true)
    }

    private var initialScrollHour: Int {
        guard let start = timedWorkDays.compactMap(\.startTime).min() else { return 8 }
        return max(calendar.component(.hour, from: start) - 1, 0)
    }

    private func eventOffset(for workDay: WorkDay) -> CGFloat {
        guard let start = workDay.startTime else { return 0 }
        return minutesSinceStartOfDay(start) / 60 * hourHeight
    }

    private func eventHeight(for workDay: WorkDay) -> CGFloat {
        guard let start = workDay.startTime, let end = workDay.endTime else { return 54 }
        let duration = max(end.timeIntervalSince(start) / 3600, 0.75)
        return CGFloat(min(duration, 24)) * hourHeight
    }

    private func minutesSinceStartOfDay(_ value: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: value)
        return CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    private func timeRange(for workDay: WorkDay) -> String {
        guard let start = workDay.startTime, let end = workDay.endTime else { return "" }
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return String(format: "%dh%02d", minutes / 60, minutes % 60)
    }
}

/// Feuille modale de sélection de date
struct DatePickerSheet: View {
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date

    init(initialDate: Date, onConfirm: @escaping (Date) -> Void) {
        self.onConfirm = onConfirm
        _draftDate = State(initialValue: CalendarGridLayout.displayCalendar.startOfDay(for: initialDate))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "calendar.selectDate".localized,
                    selection: $draftDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Button(action: {
                    onConfirm(CalendarGridLayout.displayCalendar.startOfDay(for: draftDate))
                    dismiss()
                }) {
                    Text("action.confirm".localized)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
            }
            .navigationTitle("calendar.selectDate".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}
