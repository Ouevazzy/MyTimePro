import SwiftUI
import SwiftData

struct WorkTimeSettingsSection: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkDay> {
        !$0.isDeleted &&
        ($0.typeRawValue == "workDayType.vacation" || $0.typeRawValue == "workDayType.halfDayVacation")
    }, sort: \WorkDay.date, order: .reverse) private var vacationWorkDays: [WorkDay]
    @Binding var activeSection: SettingsSection?
    @Binding var showConfetti: Bool

    @State private var showingHoursPicker = false
    @State private var weeklyHours: Double = UserSettings.shared.weeklyHours
    @State private var showVacationDetails = false
    @State private var initialBalanceUnit: BalanceUnit = .days
    @State private var editingDay: DayHourSelection?
    @State private var showRecalcConfirm = false
    @State private var isRecalculating = false
    @State private var recalcUpdatedCount: Int?
    @State private var scheduleBaseline: String = ""

    enum BalanceUnit: String, CaseIterable, Identifiable {
        case days, hours
        var id: String { rawValue }
        var label: String { self == .days ? "settings.vacation.unit.days".localized : "settings.vacation.unit.hours".localized }
    }

    private let weekDays = ["day.monday".localized, "day.tuesday".localized, "day.wednesday".localized, "day.thursday".localized, "day.friday".localized, "day.saturday".localized, "day.sunday".localized]

    private var calculatedDailyHours: Double {
        let count = settings.workingDays.filter { $0 }.count
        guard count > 0 else { return 0 }
        return (settings.weeklyHours / Double(count)).rounded(to: 2)
    }

    private var yearlyVacationStats: (used: Double, remaining: Double, carryIn: Double, annual: Double) {
        let year = Calendar.current.component(.year, from: Date())
        let entitlement = Double(settings.annualVacationDays)
        let stats = VacationCalculations.remainingStats(for: year, workDays: vacationWorkDays, annualEntitlement: entitlement)
        return (stats.used, stats.remaining, stats.carryIn, entitlement)
    }

    var body: some View {
        SettingsCard(
            title: "settings.workTime.title".localized, icon: "clock.fill", color: .blue,
            isExpanded: activeSection == .workTime,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .workTime ? nil : .workTime
                }
            }
        ) {
            VStack(spacing: 20) {
                scheduleModeRow
                if settings.useCustomDailyHours {
                    perDayHoursRow
                } else {
                    weeklyHoursRow
                    workingDaysRow
                    dailyHoursRow
                }
                recalculateRow
                hourlyRateRow
                vacationDaysRow
                advancedVacationRow
            }
            .padding()
        }
        .sheet(isPresented: $showingHoursPicker) {
            NavigationStack {
                ImprovedWeeklyHoursPickerView(
                    hours: $weeklyHours, isPresented: $showingHoursPicker,
                    onSave: { newValue in
                        settings.weeklyHours = newValue
                        settings.standardDailyHours = calculatedDailyHours
                    }
                )
            }
        }
        .sheet(isPresented: $showVacationDetails) { VacationsView() }
        .onAppear { scheduleBaseline = scheduleSignature }
        .onChange(of: activeSection) { oldValue, newValue in
            if oldValue == .workTime && newValue != .workTime {
                autoRecalculateIfNeeded()
            } else if newValue == .workTime {
                scheduleBaseline = scheduleSignature
            }
        }
        .onDisappear { autoRecalculateIfNeeded() }
    }

    // MARK: - Recalcul automatique (à la fermeture de la section)

    /// Empreinte de la configuration d'horaires. Si elle change pendant que la
    /// section est ouverte, l'historique est recalculé automatiquement à sa fermeture.
    private var scheduleSignature: String {
        let days = settings.dailyHoursByWeekday.map { String(format: "%.4f", $0) }.joined(separator: ",")
        let working = settings.workingDays.map { $0 ? "1" : "0" }.joined()
        return "\(settings.useCustomDailyHours)|\(settings.weeklyHours)|\(settings.standardDailyHours)|\(working)|\(days)"
    }

    private func autoRecalculateIfNeeded() {
        guard scheduleSignature != scheduleBaseline else { return }
        scheduleBaseline = scheduleSignature
        Task { @MainActor in
            _ = try? WorkDay.recalculateOvertime(in: modelContext)
            StatsCache.shared.invalidateAll()
            SiriSummaryCacheService().refresh(using: modelContext)
        }
    }

    // MARK: - Sub-views

    private var weeklyHoursRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.workTime.weeklyHours".localized).font(.headline)
            Button(action: { weeklyHours = settings.weeklyHours; showingHoursPicker = true }) {
                HStack {
                    Text(String(format: "%.1f%@", settings.weeklyHours, "time.hours.short".localized))
                        .font(.title).fontWeight(.semibold).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "slider.horizontal.3").foregroundStyle(.blue)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
            }
        }
    }

    private var workingDaysRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("settings.workTime.workingDays".localized).font(.headline)
            VStack(spacing: 6) {
                ForEach(weekDays.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: index < 5 ? "briefcase.fill" : "house.fill")
                            .foregroundStyle(index < 5 ? .blue : .orange).frame(width: 22)
                        Text(weekDays[index])
                        Spacer()
                        Toggle(weekDays[index], isOn: $settings.workingDays[index])
                            .labelsHidden()
                            .tint(index < 5 ? .blue : .orange)
                            .onChange(of: settings.workingDays[index]) { _, _ in
                                settings.standardDailyHours = calculatedDailyHours
                            }
                            .accessibilityLabel("Travailler le \(weekDays[index])")
                    }
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(settings.workingDays[index]
                              ? (index < 5 ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                              : Color(.systemGray6)))
                }
            }
        }
    }

    private var dailyHoursRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.workTime.dailyHours".localized).font(.headline)
            HStack {
                Text(String(format: "%.2f%@", calculatedDailyHours, "time.hours.short".localized))
                    .font(.title3).fontWeight(.semibold)
                Text("settings.calculated".localized).font(.caption).foregroundStyle(.secondary)
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    // MARK: - Per-day schedule

    /// Bascule entre horaire uniforme (heures hebdo réparties) et horaire par jour.
    private var scheduleModeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.workTime.scheduleMode".localized).font(.headline)
            Picker("settings.workTime.scheduleMode".localized, selection: Binding(
                get: { settings.useCustomDailyHours },
                set: { newValue in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        settings.useCustomDailyHours = newValue
                    }
                }
            )) {
                Text("settings.workTime.mode.uniform".localized).tag(false)
                Text("settings.workTime.mode.perDay".localized).tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    /// Éditeur d'heures cibles jour par jour (Lun…Dim). 0 h = jour de repos.
    private var perDayHoursRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("settings.workTime.perDayHours".localized).font(.headline)

            VStack(spacing: 6) {
                ForEach(weekDays.indices, id: \.self) { index in
                    let hours = dayHours(index)
                    let isWorking = hours > 0
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: index < 5 ? "briefcase.fill" : "house.fill")
                            .foregroundStyle(isWorking ? (index < 5 ? .blue : .orange) : .secondary)
                            .frame(width: 22)

                        Text(weekDays[index])

                        Spacer()

                        if isWorking {
                            Button { editingDay = DayHourSelection(id: index) } label: {
                                HStack(spacing: 4) {
                                    Text(settings.formatHours(hours))
                                        .fontWeight(.semibold).monospacedDigit()
                                    Image(systemName: "pencil").font(.caption2)
                                }
                                .foregroundStyle(.blue)
                                .padding(.vertical, 4).padding(.horizontal, 10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(weekDays[index]), \(settings.formatHours(hours))")
                        } else {
                            Text("settings.workTime.restDay".localized)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }

                        Toggle("", isOn: Binding(
                            get: { isWorking },
                            set: { on in setDayWorking(index, on: on) }
                        ))
                        .labelsHidden()
                        .tint(index < 5 ? .blue : .orange)
                        .accessibilityLabel("Travailler le \(weekDays[index])")
                    }
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(isWorking
                              ? (index < 5 ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                              : Color(.systemGray6)))
                }
            }

            HStack {
                Text("settings.workTime.weeklyTotal".localized)
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%@", weeklyTotalHours, "time.hours.short".localized))
                    .font(.headline).fontWeight(.semibold).monospacedDigit()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
        .sheet(item: $editingDay) { selection in
            NavigationStack {
                DailyHoursPickerView(
                    dayName: weekDays[selection.id],
                    hours: dayHours(selection.id)
                ) { newValue in
                    setDayHours(selection.id, hours: newValue)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func dayHours(_ index: Int) -> Double {
        let week = settings.dailyHoursByWeekday
        return (index >= 0 && index < week.count) ? week[index] : 0
    }

    private var weeklyTotalHours: Double {
        settings.dailyHoursByWeekday.reduce(0, +)
    }

    private func setDayHours(_ index: Int, hours: Double) {
        var week = settings.dailyHoursByWeekday
        while week.count < 7 { week.append(0) }
        guard index >= 0 && index < 7 else { return }
        week[index] = max(0, min(24, hours))
        settings.dailyHoursByWeekday = week
    }

    private func setDayWorking(_ index: Int, on: Bool) {
        if on {
            let current = dayHours(index)
            let fallback = settings.standardDailyHours > 0 ? settings.standardDailyHours : 8
            setDayHours(index, hours: current > 0 ? current : fallback)
        } else {
            setDayHours(index, hours: 0)
        }
    }

    // MARK: - Recalcul rétroactif

    /// Réapplique les horaires actuels à toutes les journées déjà enregistrées.
    private var recalculateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showRecalcConfirm = true
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 7))
                    Text("settings.workTime.recalculate".localized)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    if isRecalculating {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            }
            .buttonStyle(.plain)
            .disabled(isRecalculating)

            Text("settings.workTime.recalculate.help".localized)
                .font(.caption).foregroundStyle(.secondary)
        }
        .alert("settings.workTime.recalculate.confirmTitle".localized, isPresented: $showRecalcConfirm) {
            Button("action.cancel".localized, role: .cancel) {}
            Button("settings.workTime.recalculate".localized) { recalculateOvertime() }
        } message: {
            Text("settings.workTime.recalculate.confirmMessage".localized)
        }
        .alert("settings.workTime.recalculate.doneTitle".localized, isPresented: Binding(
            get: { recalcUpdatedCount != nil },
            set: { presented in if !presented { recalcUpdatedCount = nil } }
        )) {
            Button("action.done".localized, role: .cancel) { recalcUpdatedCount = nil }
        } message: {
            Text("settings.workTime.recalculate.done".localized(recalcUpdatedCount ?? 0))
        }
    }

    private func recalculateOvertime() {
        guard !isRecalculating else { return }
        isRecalculating = true
        Task { @MainActor in
            do {
                let count = try WorkDay.recalculateOvertime(in: modelContext)
                StatsCache.shared.invalidateAll()
                SiriSummaryCacheService().refresh(using: modelContext)
                Haptic.notification(.success)
                recalcUpdatedCount = count
            } catch {
                ErrorManager.shared.handle(error, context: "RecalculateOvertime")
            }
            isRecalculating = false
        }
    }

    /// Taux horaire brut, utilisé pour estimer la rémunération. 0 = désactivé.
    private var hourlyRateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.workTime.hourlyRate".localized).font(.headline)
            TextField(
                "settings.workTime.hourlyRate".localized,
                value: $settings.hourlyRate,
                format: .currency(code: Locale.current.currency?.identifier ?? "EUR")
            )
            .keyboardType(.decimalPad)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            Text("settings.workTime.hourlyRate.help".localized)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var vacationDaysRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.vacation.annualDays".localized).font(.headline)
            HStack(spacing: 15) {
                VStack(alignment: .center) {
                    Text("\(settings.annualVacationDays)").font(.title).fontWeight(.bold).foregroundStyle(.orange)
                    Text("settings.vacation.total".localized).font(.caption).foregroundStyle(.secondary)
                }.frame(width: 60)
                Spacer()
                Button(action: { if settings.annualVacationDays > 0 { settings.annualVacationDays -= 1 } }) {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(.red)
                }
                Button(action: {
                    if settings.annualVacationDays < 50 {
                        settings.annualVacationDays += 1
                        if settings.annualVacationDays == 50 {
                            withAnimation { showConfetti = true }
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation { showConfetti = false }
                            }
                        }
                    }
                }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.green)
                }
            }
            .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\("vacation.annualEntitlement".localized): \(String(format: "%.1f", yearlyVacationStats.annual))  •  \("vacation.carryIn".localized): \(String(format: "%.1f", yearlyVacationStats.carryIn))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Text("\("vacation.used".localized): ").foregroundStyle(.secondary)
                    Text(String(format: "%.1f", yearlyVacationStats.used)).fontWeight(.medium)
                    Spacer()
                    Text("\("vacation.remaining".localized): \(String(format: "%.1f", yearlyVacationStats.remaining))")
                        .foregroundStyle(.orange).fontWeight(.medium)
                }.font(.subheadline)
                ProgressView(value: yearlyVacationStats.used,
                             total: max(1, yearlyVacationStats.annual + yearlyVacationStats.carryIn))
                    .tint(.orange).scaleEffect(x: 1, y: 1.5, anchor: .center)
                Button(action: { showVacationDetails = true }) {
                    Text("settings.vacation.viewDetails".localized).font(.subheadline).foregroundStyle(.blue)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
                }
            }
        }
    }

    private var advancedVacationRow: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("settings.vacation.advancedConfig".localized).font(.headline)
            VStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.vacation.hireDate".localized).font(.subheadline).fontWeight(.medium)
                    DatePicker("settings.vacation.hireDate".localized, selection: $settings.vacationStartDate,
                               displayedComponents: [.date])
                        .datePickerStyle(.compact).padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    Text("settings.vacation.hireDateHelp".localized)
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("settings.vacation.initialBalance".localized).font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Picker("settings.vacation.unit".localized, selection: $initialBalanceUnit) {
                            ForEach(BalanceUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    HStack {
                        if initialBalanceUnit == .days {
                            TextField("", value: $settings.initialVacationDays,
                                      format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("settings.vacation.unitDays".localized).foregroundStyle(.secondary)
                            Spacer()
                            Stepper("", value: $settings.initialVacationDays, in: 0...50, step: 0.5)
                                .labelsHidden()
                        } else {
                            TextField("", value: Binding(
                                get: { settings.initialVacationDays * settings.standardDailyHours },
                                set: { newHours in
                                    let daily = settings.standardDailyHours
                                    settings.initialVacationDays = daily > 0 ? (newHours / daily) : 0
                                }
                            ), format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 80)
                            Text("settings.vacation.unitHours".localized).foregroundStyle(.secondary)
                            Spacer()
                            Stepper("", value: Binding(
                                get: { settings.initialVacationDays * settings.standardDailyHours },
                                set: { newHours in
                                    let daily = settings.standardDailyHours
                                    settings.initialVacationDays = daily > 0 ? (newHours / daily) : 0
                                }
                            ), in: 0...(50 * max(1, settings.standardDailyHours)), step: max(0.5, settings.standardDailyHours / 2))
                                .labelsHidden()
                        }
                    }
                    .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

                    // Équivalence dans l'autre unité
                    Text(initialBalanceUnit == .days
                         ? "settings.vacation.equivalentHours".localized(settings.initialVacationDays * settings.standardDailyHours)
                         : "settings.vacation.equivalentDays".localized(settings.initialVacationDays))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            let calendar = Calendar.current
            let startYear = calendar.component(.year, from: settings.vacationStartDate)
            let currentYear = calendar.component(.year, from: Date())
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.vacation.summary.initial".localized(
                    startYear,
                    settings.initialVacationDays,
                    "settings.vacation.unitDays".localized,
                    settings.initialVacationDays * settings.standardDailyHours,
                    "time.hours.short".localized,
                    "vacation.initialBalance".localized
                ))
                if currentYear > startYear {
                    Text("settings.vacation.summary.following".localized(
                        startYear + 1,
                        settings.annualVacationDays,
                        "settings.vacation.unitDays".localized,
                        "vacation.carryIn".localized.lowercased()
                    ))
                }
                Text("settings.vacation.summary.carryover".localized).foregroundStyle(.secondary)
            }
            .font(.caption).foregroundStyle(.blue).padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
        )
    }
}

private struct DayHourSelection: Identifiable {
    let id: Int
}

/// Sélecteur d'heures cibles pour un jour donné (0–24 h, pas de 15 minutes).
private struct DailyHoursPickerView: View {
    let dayName: String
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hourSelection: Int
    @State private var minuteSelection: Int

    private let minuteSteps = [0, 15, 30, 45]

    init(dayName: String, hours: Double, onSave: @escaping (Double) -> Void) {
        self.dayName = dayName
        self.onSave = onSave
        let clamped = max(0, min(24, hours))
        let h = Int(clamped)
        let rawMinutes = Int(((clamped - Double(h)) * 60.0).rounded())
        let nearest = [0, 15, 30, 45].min(by: { abs($0 - rawMinutes) < abs($1 - rawMinutes) }) ?? 0
        _hourSelection = State(initialValue: min(h, 24))
        _minuteSelection = State(initialValue: nearest >= 60 ? 45 : nearest)
    }

    private var selectedHours: Double {
        min(24, Double(hourSelection) + Double(minuteSelection) / 60.0)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(formattedValue)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.blue)
                .contentTransition(.numericText())
                .padding(.top, 8)

            HStack(spacing: 0) {
                Picker("settings.workTime.hours".localized, selection: $hourSelection) {
                    ForEach(0...24, id: \.self) { value in
                        Text("\(value) \("time.hours.short".localized)").tag(value)
                    }
                }
                .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()

                Picker("settings.workTime.minutes".localized, selection: $minuteSelection) {
                    ForEach(minuteSteps, id: \.self) { value in
                        Text(String(format: "%02d min", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
            }
            .frame(height: 170)

            Button {
                onSave(selectedHours)
                dismiss()
            } label: {
                Text("action.save".localized)
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(dayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("action.cancel".localized) { dismiss() }
            }
        }
    }

    private var formattedValue: String {
        if UserSettings.shared.useDecimalHours {
            return String(format: "%.2f", selectedHours) + "h"
        }
        return String(format: "%dh%02d", hourSelection, minuteSelection)
    }
}

#Preview {
    WorkTimeSettingsSection(
        settings: UserSettings.shared,
        activeSection: .constant(.workTime),
        showConfetti: .constant(false)
    )
    .padding()
    .modelContainer(for: WorkDay.self, inMemory: true)
}
