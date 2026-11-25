//
//  SwissHolidaysView.swift
//  WorkTimer
//
//  Choix du canton, liste des jours fériés et ajout aux journées (Pro).
//

import SwiftData
import SwiftUI

/// Ajout de jours fériés comme journées. Rien n'est ajouté sans action de l'utilisateur.
@MainActor
struct SwissHolidayImporter {
    let context: ModelContext
    var settings: UserSettings = .shared
    var today = Date()

    /// Jours ajoutables : jour normalement travaillé, sans saisie, férié toute
    /// la journée, et pas au-delà d'un an (même limite que la saisie manuelle).
    func missing(in holidays: [SwissHolidayDay]) throws -> [SwissHolidayDay] {
        var taken = Set(try entries(for: holidays).keys)
        return holidays.filter { day in
            guard canAdd(day) else { return false }
            return taken.insert(Calendar.current.startOfDay(for: day.date)).inserted
        }
    }

    func canAdd(_ day: SwissHolidayDay) -> Bool {
        let limit = Calendar.current.date(byAdding: .year, value: 1, to: today) ?? .distantFuture
        return !day.isAfternoonOnly
            && day.date <= limit
            && settings.expectedDailyHours(for: day.date) > 0
    }

    func entries(for holidays: [SwissHolidayDay]) throws -> [Date: [WorkDay]] {
        guard let first = holidays.map(\.date).min(), let last = holidays.map(\.date).max(),
              let end = Calendar.current.date(byAdding: .day, value: 1, to: last) else { return [:] }
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate { $0.date >= first && $0.date < end && !$0.isDeleted }
        )
        return Dictionary(grouping: try context.fetch(descriptor)) {
            Calendar.current.startOfDay(for: $0.date)
        }
    }

    /// Ajoute les jours encore libres et renvoie leur nombre.
    @discardableResult
    func add(_ holidays: [SwissHolidayDay]) throws -> Int {
        let days = try missing(in: holidays)
        guard !days.isEmpty else { return 0 }
        do {
            for day in days {
                let entry = WorkDay(
                    date: Calendar.current.startOfDay(for: day.date),
                    breakDuration: 0,
                    type: .holiday,
                    note: day.holiday.localizedName
                )
                context.insert(entry)
                StatsCache.shared.onWorkDayChanged(entry)
            }
            _ = try WorkDay.reconcileDailyOvertime(in: context, for: days.map(\.date))
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        StatsCache.shared.invalidateAll()
        SiriSummaryCacheService().refresh(using: context)
        NotificationCenter.default.post(name: .swissHolidaysAdded, object: nil)
        return days.count
    }
}

extension Notification.Name {
    static let swissHolidaysAdded = Notification.Name("swissHolidaysAdded")
}

extension UserSettings {
    /// Région choisie, si la fonction est active (Pro).
    @MainActor var activeHolidayRegion: SwissHolidayRegion? {
        StoreManager.shared.isPro ? SwissHolidayRegion(rawValue: holidayRegionID) : nil
    }
}

struct SwissHolidaysView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = UserSettings.shared
    @State private var year = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var entries: [Date: [WorkDay]] = [:]
    @State private var missing: [SwissHolidayDay] = []
    @State private var showConfirmation = false

    private var region: SwissHolidayRegion? { SwissHolidayRegion(rawValue: settings.holidayRegionID) }
    private var holidays: [SwissHolidayDay] { region?.holidays(in: year) ?? [] }
    private var importer: SwissHolidayImporter { SwissHolidayImporter(context: modelContext) }
    private var years: [Int] {
        let current = Calendar(identifier: .gregorian).component(.year, from: Date())
        return [current, current + 1]
    }

    private var cantonSelection: Binding<SwissCanton?> {
        Binding(
            get: { region?.canton },
            set: { settings.holidayRegionID = $0?.regions.first?.rawValue ?? "" }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("swissHolidays.canton".localized, selection: cantonSelection) {
                    Text("swissHolidays.none".localized).tag(SwissCanton?.none)
                    ForEach(cantons) { canton in
                        Text(canton.localizedName).tag(SwissCanton?.some(canton))
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("swissHolidays.canton")

                if let region, region.canton.regions.count > 1 {
                    Picker("swissHolidays.region".localized, selection: $settings.holidayRegionID) {
                        ForEach(region.canton.regions) { region in
                            Text(region.localizedName).tag(region.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("swissHolidays.region")
                }
            }

            if region != nil {
                Section {
                    Picker("calendar.mode.year".localized, selection: $year) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    ForEach(holidays) { row($0) }
                } footer: {
                    Text("swissHolidays.source".localized)
                }

                if !missing.isEmpty {
                    Section {
                    Button {
                        showConfirmation = true
                    } label: {
                        Label("swissHolidays.addAll".localized(missing.count), systemImage: "calendar.badge.plus")
                    }
                    .accessibilityIdentifier("swissHolidays.addAll")
                } footer: {
                    Text("swissHolidays.addAll.help".localized)
                    }
                }
            }
        }
        .navigationTitle("swissHolidays.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("action.close".localized) { dismiss() }
            }
        }
        .task(id: "\(settings.holidayRegionID)-\(year)") { reload() }
        .alert("swissHolidays.confirm.title".localized, isPresented: $showConfirmation) {
            Button("action.add".localized) { addMissing() }
            Button("action.cancel".localized, role: .cancel) {}
        } message: {
            Text("swissHolidays.confirm.message".localized(missing.count))
        }
        .withErrorHandling()
    }

    private var cantons: [SwissCanton] {
        SwissCanton.allCases.sorted {
            $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending
        }
    }

    private func row(_ day: SwissHolidayDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.title)
                Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let type = entries[Calendar.current.startOfDay(for: day.date)]?.first?.type {
                Label(type.localizedName, systemImage: type.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if settings.expectedDailyHours(for: day.date) == 0 {
                Text("swissHolidays.dayOff".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        do {
            entries = try importer.entries(for: holidays)
            missing = try importer.missing(in: holidays)
        } catch {
            ErrorManager.shared.handle(error, context: "SwissHolidaysLoad")
        }
    }

    private func addMissing() {
        do {
            try importer.add(holidays)
            Haptic.notification(.success)
        } catch {
            ErrorManager.shared.handle(error, context: "SwissHolidaysAdd")
        }
        reload()
    }
}

#Preview {
    NavigationStack { SwissHolidaysView() }
        .modelContainer(for: WorkDay.self, inMemory: true)
}
