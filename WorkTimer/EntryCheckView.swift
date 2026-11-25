//
//  EntryCheckView.swift
//  WorkTimer
//
//  Liste des journées à vérifier et rappel sur l'accueil (Pro).
//

import SwiftData
import SwiftUI

struct EntryCheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("entryCheck.showOnHome") private var showOnHome = true
    @State private var issues: [EntryIssue] = []
    @State private var ignoredCount = 0
    @State private var isLoaded = false
    @State private var editing: WorkDay?

    var body: some View {
        List {
            Section {
                if issues.isEmpty {
                    if isLoaded {
                        Label("entryCheck.empty".localized, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("entryCheck.empty")
                    }
                } else {
                    ForEach(issues) { issue in
                        Button {
                            open(issue)
                        } label: {
                            row(issue)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("entryCheck.\(issue.id)")
                        .swipeActions {
                            Button("entryCheck.ignore".localized) { ignore(issue) }
                                .tint(.gray)
                        }
                        .contextMenu {
                            Button {
                                ignore(issue)
                            } label: {
                                Label("entryCheck.ignore".localized, systemImage: "eye.slash")
                            }
                        }
                    }
                }
            } footer: {
                Text("entryCheck.help".localized(EntryCheck.windowDays))
            }

            Section {
                Toggle("entryCheck.showOnHome".localized, isOn: $showOnHome)
                    .accessibilityIdentifier("entryCheck.showOnHome")
                if ignoredCount > 0 {
                    Button("entryCheck.restoreIgnored".localized(ignoredCount)) {
                        EntryCheck.clearIgnored()
                        reload()
                    }
                    .accessibilityIdentifier("entryCheck.restoreIgnored")
                }
            } footer: {
                Text("entryCheck.disclaimer".localized)
            }
        }
        .navigationTitle("entryCheck.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("action.close".localized) { dismiss() }
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $editing, onDismiss: reload) { workDay in
            NavigationStack { AddEditWorkDayView(workDay: workDay) }
        }
        .withErrorHandling()
    }

    private func row(_ issue: EntryIssue) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon(issue.kind))
                .foregroundStyle(.orange)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                Text(description(issue.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func icon(_ kind: EntryIssue.Kind) -> String {
        switch kind {
        case .missingDay: "calendar.badge.exclamationmark"
        case .missingEnd: "clock.badge.exclamationmark"
        case .shortBreak: "pause.circle"
        }
    }

    private func description(_ kind: EntryIssue.Kind) -> String {
        switch kind {
        case .missingDay: "entryCheck.missingDay".localized
        case .missingEnd: "entryCheck.missingEnd".localized
        case .shortBreak(let minutes, let minimum): "entryCheck.shortBreak".localized(minutes, minimum)
        }
    }

    private func open(_ issue: EntryIssue) {
        guard let id = issue.entryID else {
            editing = WorkDay(date: Calendar.current.startOfDay(for: issue.date))
            return
        }
        do {
            let descriptor = FetchDescriptor<WorkDay>(predicate: #Predicate { $0.id == id })
            if let entry = try modelContext.fetch(descriptor).first { editing = entry } else { reload() }
        } catch {
            ErrorManager.shared.handle(error, context: "EntryCheckOpen")
        }
    }

    private func ignore(_ issue: EntryIssue) {
        EntryCheck.ignore(issue)
        withAnimation { reload() }
    }

    private func reload() {
        do {
            let all = try EntryCheck.load(in: modelContext, region: UserSettings.shared.activeHolidayRegion)
            let ignored = EntryCheck.ignored()
            issues = all.filter { !ignored.contains($0.id) }
            ignoredCount = all.count - issues.count
            isLoaded = true
        } catch {
            ErrorManager.shared.handle(error, context: "EntryCheckLoad")
        }
    }
}

/// Rappel discret sur l'accueil, présent seulement s'il reste des jours à vérifier.
struct EntryCheckCard: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("entryCheck.home".localized(count))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .dsContentSurface(cornerRadius: DS.Radius.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.entryCheck")
    }
}

#Preview {
    NavigationStack { EntryCheckView() }
        .modelContainer(for: WorkDay.self, inMemory: true)
}
