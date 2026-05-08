import SwiftUI
import SwiftData

struct WorkTimeSettingsSection: View {
    @Bindable var settings: UserSettings
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    @Binding var activeSection: SettingsSection?
    @Binding var showConfetti: Bool

    @State private var showingHoursPicker = false
    @State private var weeklyHours: Double = UserSettings.shared.weeklyHours
    @State private var showVacationDetails = false
    @State private var initialBalanceUnit: BalanceUnit = .days

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
        let stats = VacationCalculations.remainingStats(for: year, workDays: workDays, annualEntitlement: entitlement)
        return (stats.used, stats.remaining, stats.carryIn, entitlement)
    }

    var body: some View {
        SettingsCard(
            title: "Horaires de travail", icon: "clock.fill", color: .blue,
            isExpanded: activeSection == .workTime,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .workTime ? nil : .workTime
                }
            }
        ) {
            VStack(spacing: 20) {
                weeklyHoursRow
                workingDaysRow
                dailyHoursRow
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
    }

    // MARK: - Sub-views

    private var weeklyHoursRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.workTime.weeklyHours".localized).font(.headline)
            Button(action: { weeklyHours = settings.weeklyHours; showingHoursPicker = true }) {
                HStack {
                    Text(String(format: "%.1f", settings.weeklyHours) + "h")
                        .font(.title).fontWeight(.semibold).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "slider.horizontal.3").foregroundColor(.blue)
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
                            .foregroundColor(index < 5 ? .blue : .orange).frame(width: 22)
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
                Text(String(format: "%.2f", calculatedDailyHours) + "h")
                    .font(.title3).fontWeight(.semibold)
                Text("(calculé automatiquement)").font(.caption).foregroundColor(.secondary)
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    private var vacationDaysRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.vacation.annualDays".localized).font(.headline)
            HStack(spacing: 15) {
                VStack(alignment: .center) {
                    Text("\(settings.annualVacationDays)").font(.title).fontWeight(.bold).foregroundColor(.orange)
                    Text("Total").font(.caption).foregroundColor(.secondary)
                }.frame(width: 60)
                Spacer()
                Button(action: { if settings.annualVacationDays > 0 { settings.annualVacationDays -= 1 } }) {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.red)
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
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.green)
                }
            }
            .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Droits: \(String(format: "%.1f", yearlyVacationStats.annual))  •  Report: \(String(format: "%.1f", yearlyVacationStats.carryIn))")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                HStack {
                    Text("Utilisés: ").foregroundColor(.secondary)
                    Text(String(format: "%.1f", yearlyVacationStats.used)).fontWeight(.medium)
                    Spacer()
                    Text("Solde: \(String(format: "%.1f", yearlyVacationStats.remaining))")
                        .foregroundColor(.orange).fontWeight(.medium)
                }.font(.subheadline)
                ProgressView(value: yearlyVacationStats.used,
                             total: max(1, yearlyVacationStats.annual + yearlyVacationStats.carryIn))
                    .tint(.orange).scaleEffect(x: 1, y: 1.5, anchor: .center)
                Button(action: { showVacationDetails = true }) {
                    Text("settings.vacation.viewDetails".localized).font(.subheadline).foregroundColor(.blue)
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
                    DatePicker("Date de début", selection: $settings.vacationStartDate,
                               displayedComponents: [.date])
                        .datePickerStyle(.compact).padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    Text("settings.vacation.hireDateHelp".localized)
                        .font(.caption).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("settings.vacation.initialBalance".localized).font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Picker("Unité", selection: $initialBalanceUnit) {
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
                            Text("settings.vacation.unitDays".localized).foregroundColor(.secondary)
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
                            Text("settings.vacation.unitHours".localized).foregroundColor(.secondary)
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
                         ? String(format: "≈ %.1f heures", settings.initialVacationDays * settings.standardDailyHours)
                         : String(format: "≈ %.1f jours", settings.initialVacationDays))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            let calendar = Calendar.current
            let startYear = calendar.component(.year, from: settings.vacationStartDate)
            let currentYear = calendar.component(.year, from: Date())
            VStack(alignment: .leading, spacing: 4) {
                Text("• \(startYear): \(String(format: "%.1f", settings.initialVacationDays)) jours (\(String(format: "%.1fh", settings.initialVacationDays * settings.standardDailyHours))) (solde initial)")
                if currentYear > startYear {
                    Text("• \(startYear + 1) et après: \(settings.annualVacationDays) jours/an + report")
                }
                Text("• Le solde non utilisé est reporté à l'année suivante").foregroundColor(.secondary)
            }
            .font(.caption).foregroundColor(.blue).padding()
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

#Preview {
    WorkTimeSettingsSection(
        settings: UserSettings.shared,
        activeSection: .constant(.workTime),
        showConfetti: .constant(false)
    )
    .padding()
    .modelContainer(for: WorkDay.self, inMemory: true)
}
