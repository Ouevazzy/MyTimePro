//
//  LiveTimerCard.swift
//  WorkTimer
//
//  Carte d'accueil du chronomètre en direct : pointer arrivée / pause / départ.
//

import SwiftUI
import SwiftData

struct LiveTimerCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = TimerManager.shared

    // Édition de l'entrée générée au départ.
    @State private var editingWorkDay: WorkDay?
    @State private var showLongSessionSheet = false
    @State private var bounce = 0

    /// Une session en cours reste visible même si la carte est masquée :
    /// elle peut avoir été lancée par Siri ou depuis la montre.
    static func isVisible(settingEnabled: Bool, sessionActive: Bool) -> Bool {
        settingEnabled || sessionActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header

            switch timer.state {
            case .idle:
                idleContent
            case .running, .paused:
                activeContent
            }
        }
        .padding()
        .dsContentSurface(cornerRadius: DS.Radius.card)
        .animation(reduceMotion ? nil : DS.Animation.cardToggle, value: timer.state)
        .sheet(item: $editingWorkDay) { day in
            NavigationStack {
                AddEditWorkDayView(workDay: day)
            }
        }
        .sheet(isPresented: $showLongSessionSheet) {
            if let start = timer.startDate {
                NavigationStack {
                    LongSessionSheet(
                        start: start,
                        onSave: { endDate in
                            let outcome = timer.stopAndSave(in: modelContext, at: endDate)
                            if outcome.result != .saved { Haptic.notification(.warning) }
                        },
                        onDiscard: {
                            timer.reset()
                            Haptic.notification(.warning)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "timer")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(accentColor)
                .frame(width: DS.Spacing.xl)
                .accessibilityHidden(true)

            Text(statusTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            if timer.isActive, let start = timer.startDate {
                Text("timer.startedAt".localized(start.formatted(.dateTime.hour().minute())))
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("timer.idle.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(DS.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Haptic.impact(.medium)
                bounce += 1
                timer.start()
            } label: {
                Label("timer.clockIn".localized, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xs)
                    .symbolEffect(.bounce, value: bounce)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)
            .accessibilityIdentifier("timer.clockIn")
        }
    }

    // MARK: - Active (running / paused)

    private var activeContent: some View {
        VStack(spacing: DS.Spacing.md) {
            // Compteur qui tourne — mis à jour chaque seconde.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                VStack(spacing: DS.Spacing.xs) {
                    Text(Self.formatElapsed(timer.workedSeconds(at: now)))
                        .font(.system(size: DS.Font.statDisplay, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    let breakSeconds = timer.breakSeconds(at: now)
                    if breakSeconds >= 60 || timer.state == .paused {
                        Label(
                            "timer.breakLabel".localized(Self.formatElapsed(breakSeconds)),
                            systemImage: "pause.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(timer.state == .paused ? .orange : DS.Colors.secondaryText)
                        .contentTransition(.numericText())
                    }

                    if timer.exceedsMaximumDuration(at: now) {
                        Label("timer.longSession.warning".localized, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("timer.accessibility.elapsed".localized(Self.formatElapsed(timer.workedSeconds(at: now)))))
            }

            HStack(spacing: DS.Spacing.sm) {
                // Pause / Reprendre
                Button {
                    Haptic.impact(.light)
                    if timer.state == .paused { timer.resume() } else { timer.pause() }
                } label: {
                    Label(
                        timer.state == .paused ? "timer.resume".localized : "timer.pause".localized,
                        systemImage: timer.state == .paused ? "play.fill" : "pause.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xs)
                }
                .buttonStyle(.glass)
                .tint(.orange)

                // Départ
                Button {
                    stopTimer()
                } label: {
                    Label("timer.clockOut".localized, systemImage: "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .accessibilityIdentifier("timer.clockOut")
            }
        }
    }

    // MARK: - Actions

    private func stopTimer() {
        let outcome = timer.stopAndSave(in: modelContext)
        switch outcome.result {
        case .saved:
            editingWorkDay = outcome.workDay
        case .tooShort:
            Haptic.notification(.warning)
        case .tooLong:
            showLongSessionSheet = true
        case .notRunning, .failed:
            Haptic.notification(.error)
        }
    }

    // MARK: - Presentation helpers

    private var accentColor: Color {
        switch timer.state {
        case .idle: return .blue
        case .running: return .green
        case .paused: return .orange
        }
    }

    private var statusTitle: String {
        switch timer.state {
        case .idle: return "timer.title".localized
        case .running: return "timer.running".localized
        case .paused: return "timer.paused".localized
        }
    }

    /// Formate un intervalle en HH:MM:SS (ou H:MM:SS).
    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}

// MARK: - Session de plus de 24 h

/// Une session oubliée n'est jamais enregistrée telle quelle : l'utilisateur
/// indique sa véritable heure de fin ou abandonne la session.
private struct LongSessionSheet: View {
    let start: Date
    let onSave: (Date) -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var endDate: Date
    @State private var confirmDiscard = false

    init(start: Date, onSave: @escaping (Date) -> Void, onDiscard: @escaping () -> Void) {
        self.start = start
        self.onSave = onSave
        self.onDiscard = onDiscard
        let expectedHours = UserSettings.shared.expectedDailyHours(for: start)
        let defaultHours = expectedHours > 0 ? expectedHours : 8
        _endDate = State(initialValue: start.addingTimeInterval(defaultHours * 3600))
    }

    var body: some View {
        Form {
            Section {
                Text("timer.longSession.message".localized)
                    .font(.subheadline)
                    .foregroundStyle(DS.Colors.secondaryText)

                DatePicker(
                    "timer.longSession.endTime".localized,
                    selection: $endDate,
                    in: start.addingTimeInterval(60)...start.addingTimeInterval(TimerManager.maximumSessionSeconds),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section {
                Button("timer.longSession.discard".localized, role: .destructive) {
                    confirmDiscard = true
                }
            }
        }
        .navigationTitle("timer.longSession.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("action.cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("action.save".localized) {
                    onSave(endDate)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog(
            "timer.longSession.discardConfirm".localized,
            isPresented: $confirmDiscard,
            titleVisibility: .visible
        ) {
            Button("timer.longSession.discard".localized, role: .destructive) {
                onDiscard()
                dismiss()
            }
            Button("action.cancel".localized, role: .cancel) {}
        }
    }
}

// Permet la présentation via `.sheet(item:)`.
extension WorkDay: Identifiable {}

#Preview {
    ScrollView {
        LiveTimerCard()
            .padding()
    }
    .modelContainer(for: WorkDay.self, inMemory: true)
}
