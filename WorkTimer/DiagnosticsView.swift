import SwiftUI
import SwiftData

/// Vue de diagnostic pour vérifier les calculs d'heures et de congés
struct DiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]

    @State private var selectedYear: Int
    @State private var showingExportAlert = false
    @State private var diagnosticReport = ""
    @State private var showingRecalculateAlert = false
    @State private var showingRecalculateResult = false
    @State private var recalculateResultMessage = ""
    
    let settings = UserSettings.shared
    
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...(currentYear + 1))
    }
    
    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Section Paramètres
                Section {
                    configurationRow("diagnostics.config.startDate".localized, value: formatDate(settings.vacationStartDate))
                    configurationRow("diagnostics.vacation.initial".localized, value: "diagnostics.days.decimal2".localized(settings.initialVacationDays))
                    configurationRow("diagnostics.config.annual".localized, value: "diagnostics.days.count".localized(settings.annualVacationDays))
                    configurationRow("diagnostics.config.weeklyHours".localized, value: String(format: "%.1f h", settings.weeklyHours))
                    configurationRow("diagnostics.config.dailyHours".localized, value: String(format: "%.2f h", settings.standardDailyHours))
                } header: {
                    Label("diagnostics.config.header".localized, systemImage: "gearshape")
                }
                
                // Section Sélection d'année
                Section {
                    Picker("diagnostics.year".localized, selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("diagnostics.selection.header".localized, systemImage: "calendar")
                }
                
                // Section Statistiques de l'année
                Section {
                    let stats = yearStats
                    
                    diagnosticRow("diagnostics.stats.totalEntries".localized, value: "\(stats.totalEntries)", icon: "doc.text", color: .blue)
                    diagnosticRow("diagnostics.stats.deletedEntries".localized, value: "\(stats.deletedEntries)", icon: "trash", color: .red)
                    diagnosticRow("diagnostics.stats.activeEntries".localized, value: "\(stats.activeEntries)", icon: "checkmark.circle", color: .green)
                    
                    Divider()
                    
                    diagnosticRow("diagnostics.stats.workDays".localized, value: "\(stats.workDays)", icon: "briefcase", color: .blue)
                    diagnosticRow("diagnostics.stats.totalHours".localized, value: formatHours(stats.totalHours), icon: "clock", color: .blue)
                    diagnosticRow("diagnostics.stats.overtime".localized, value: formatSeconds(stats.overtimeSeconds), icon: "clock.badge.exclamationmark", color: stats.overtimeSeconds >= 0 ? .green : .red)
                    
                    Divider()
                    
                    diagnosticRow("diagnostics.stats.fullVacation".localized, value: "\(stats.vacationDays)", icon: "sun.max", color: .orange)
                    diagnosticRow("diagnostics.stats.halfDays".localized, value: "\(stats.halfVacationDays)", icon: "sun.min", color: .orange)
                    diagnosticRow("diagnostics.stats.totalVacation".localized, value: "diagnostics.days.short1".localized(stats.totalVacationDays), icon: "sun.max.fill", color: .orange)
                    diagnosticRow("diagnostics.stats.sickDays".localized, value: "\(stats.sickDays)", icon: "cross.case", color: .red)
                    diagnosticRow("diagnostics.stats.holidays".localized, value: "\(stats.holidays)", icon: "star", color: .yellow)
                    diagnosticRow("diagnostics.stats.compensatory".localized, value: "\(stats.compensatoryDays)", icon: "arrow.2.squarepath", color: .green)
                    
                } header: {
                    Label("\("diagnostics.stats.header".localized) \(String(selectedYear))", systemImage: "chart.bar")
                }
                
                // Section Calcul des congés détaillé
                Section {
                    let vacationCalc = vacationCalculation
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("diagnostics.vacation.calculation".localized)
                            .font(.headline)
                        
                        if vacationCalc.isStartYear {
                            calculationStep("diagnostics.vacation.initial".localized, value: vacationCalc.carryIn, color: .purple)
                            calculationStep("diagnostics.vacation.used".localized, value: -vacationCalc.used, color: .orange)
                            Divider()
                            calculationStep("diagnostics.vacation.remaining".localized, value: vacationCalc.remaining, color: vacationCalc.remaining > 0 ? .green : .red, bold: true)
                        } else {
                            calculationStep("diagnostics.vacation.carryIn".localized, value: vacationCalc.carryIn, color: .purple)
                            calculationStep("diagnostics.vacation.entitlement".localized, value: vacationCalc.annual, color: .blue)
                            calculationStep("diagnostics.vacation.used".localized, value: -vacationCalc.used, color: .orange)
                            Divider()
                            calculationStep("diagnostics.vacation.remaining".localized, value: vacationCalc.remaining, color: vacationCalc.remaining > 0 ? .green : .red, bold: true)
                        }
                    }
                    .padding(.vertical, 8)
                    
                } header: {
                    Label("\("diagnostics.vacation.header".localized) \(String(selectedYear))", systemImage: "function")
                }
                
                // Section Détail du report par année
                Section {
                    ForEach(carryoverHistory, id: \.year) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(String(entry.year))
                                    .font(.headline)
                                Spacer()
                                Text("diagnostics.history.remaining".localized(entry.remaining))
                                    .foregroundStyle(entry.remaining > 0 ? .green : .red)
                            }
                            
                            HStack {
                                if entry.isStartYear {
                                    Text("diagnostics.history.initial".localized(String(format: "%.1f", entry.carryIn)))
                                } else {
                                    Text("diagnostics.history.carry".localized(String(format: "%.1f", entry.carryIn), String(format: "%.1f", entry.entitlement)))
                                }
                                Text("diagnostics.history.used".localized(String(format: "%.1f", entry.used)))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("diagnostics.history.header".localized, systemImage: "clock.arrow.circlepath")
                }
                
                // Section Vérification des heures
                Section {
                    let hoursCheck = hoursVerification
                    
                    diagnosticRow("diagnostics.hours.calculated".localized, value: formatHours(hoursCheck.fromWorkDays), icon: "doc.text", color: .blue)
                    diagnosticRow("diagnostics.hours.recalculated".localized, value: formatHours(hoursCheck.recalculated), icon: "arrow.triangle.2.circlepath", color: .blue)
                    
                    let difference = abs(hoursCheck.fromWorkDays - hoursCheck.recalculated)
                    let isMatching = difference < 0.01
                    
                    HStack {
                        Image(systemName: isMatching ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(isMatching ? .green : .orange)
                        Text(isMatching ? "diagnostics.hours.matching".localized : "diagnostics.hours.differenceValue".localized(formatHours(difference)))
                            .foregroundStyle(isMatching ? .green : .orange)
                    }
                    
                } header: {
                    Label("diagnostics.hours.header".localized, systemImage: "checkmark.shield")
                }
                
                // Section Détection des doublons
                Section {
                    let duplicates = duplicateEntries
                    
                    if duplicates.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("diagnostics.duplicates.none".localized)
                                .foregroundStyle(.green)
                        }
                    } else {
                        diagnosticRow("diagnostics.duplicates.datesCount".localized, value: "\(duplicates.count)", icon: "exclamationmark.triangle.fill", color: .orange)
                        diagnosticRow("diagnostics.duplicates.entriesCount".localized, value: "\(duplicates.reduce(0) { $0 + $1.entries.count })", icon: "doc.on.doc", color: .orange)
                        
                        ForEach(duplicates, id: \.dateString) { duplicate in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundStyle(.orange)
                                    Text(duplicate.dateString)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("diagnostics.duplicates.entriesBadge".localized(duplicate.entries.count))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                
                                ForEach(duplicate.entries, id: \.id) { entry in
                                    HStack {
                                        Text("• \(entry.type.displayName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if entry.type.isWorkDay, let start = entry.startTime, let end = entry.endTime {
                                            Text("\(formatTime(start)) - \(formatTime(end))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 24)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Label("\("diagnostics.duplicates.header".localized) \(String(selectedYear))", systemImage: "doc.on.doc")
                }
                
                // Section Outils de correction
                Section {
                    Button(action: { showingRecalculateAlert = true }) {
                        Label("diagnostics.recalculate.allYear".localized(String(selectedYear)), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .foregroundStyle(.orange)
                    
                    Text("diagnostics.recalculate.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("diagnostics.tools.header".localized, systemImage: "wrench.and.screwdriver")
                }
                
                // Bouton d'export
                Section {
                    Button(action: generateReport) {
                        Label("diagnostics.export.report".localized, systemImage: "doc.badge.gearshape")
                    }
                } header: {
                    Label("diagnostics.export.header".localized, systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("diagnostics.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.close".localized) {
                        dismiss()
                    }
                }
            }
            .alert("diagnostics.report.generated.title".localized, isPresented: $showingExportAlert) {
                Button("OK", role: .cancel) { }
                Button("diagnostics.report.copy".localized) {
                    UIPasteboard.general.string = diagnosticReport
                }
            } message: {
                Text("diagnostics.report.copyQuestion".localized)
            }
            .alert("diagnostics.recalculate.title".localized, isPresented: $showingRecalculateAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("diagnostics.recalculate.confirm".localized, role: .destructive) {
                    recalculateAllHours()
                }
            } message: {
                Text("diagnostics.recalculate.confirmMessage".localized(String(selectedYear)))
            }
            .alert("diagnostics.recalculate.completed.title".localized, isPresented: $showingRecalculateResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(recalculateResultMessage)
            }
        }
    }
    
    // MARK: - Computed Properties

    private var selectedYearWorkDays: [WorkDay] {
        let calendar = Calendar.current
        return workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
    }

    private var activeSelectedYearWorkDays: [WorkDay] {
        selectedYearWorkDays.filter { !$0.isDeleted }
    }

    private var yearStats: YearStatistics {
        let yearWorkDays = selectedYearWorkDays
        let activeWorkDays = activeSelectedYearWorkDays
        
        return YearStatistics(
            totalEntries: yearWorkDays.count,
            deletedEntries: yearWorkDays.count - activeWorkDays.count,
            activeEntries: activeWorkDays.count,
            workDays: Set(
                activeWorkDays
                    .filter { $0.type == .work }
                    .map { Calendar.current.startOfDay(for: $0.date) }
            ).count,
            totalHours: activeWorkDays.filter { $0.type == .work }.reduce(0) { $0 + $1.totalHours },
            overtimeSeconds: activeWorkDays.reduce(0) { $0 + $1.overtimeSeconds },
            vacationDays: activeWorkDays.filter { $0.type == .vacation }.count,
            halfVacationDays: activeWorkDays.filter { $0.type == .halfDayVacation }.count,
            totalVacationDays: activeWorkDays.reduce(0.0) { total, day in
                switch day.type {
                case .vacation: return total + 1
                case .halfDayVacation: return total + 0.5
                default: return total
                }
            },
            sickDays: activeWorkDays.filter { $0.type == .sickLeave }.count,
            holidays: activeWorkDays.filter { $0.type == .holiday }.count,
            compensatoryDays: activeWorkDays.filter { $0.type == .compensatory }.count
        )
    }
    
    private var vacationCalculation: VacationCalc {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        let entitlement = Double(settings.annualVacationDays)
        
        let stats = VacationCalculations.remainingStats(
            for: selectedYear,
            workDays: workDays,
            annualEntitlement: entitlement
        )
        
        let isStartYear = selectedYear == startYear
        let annual = isStartYear ? 0 : entitlement
        
        return VacationCalc(
            isStartYear: isStartYear,
            carryIn: stats.carryIn,
            annual: annual,
            used: stats.used,
            remaining: stats.remaining
        )
    }
    
    private var carryoverHistory: [CarryoverEntry] {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        let currentYear = calendar.component(.year, from: Date())
        let entitlement = Double(settings.annualVacationDays)
        
        var entries: [CarryoverEntry] = []
        
        for year in startYear...currentYear {
            let stats = VacationCalculations.remainingStats(
                for: year,
                workDays: workDays,
                annualEntitlement: entitlement
            )
            
            let isStart = year == startYear
            let yearEntitlement = isStart ? 0 : entitlement
            
            entries.append(CarryoverEntry(
                year: year,
                isStartYear: isStart,
                carryIn: stats.carryIn,
                entitlement: yearEntitlement,
                used: stats.used,
                remaining: stats.remaining
            ))
        }
        
        return entries
    }
    
    private var hoursVerification: HoursCheck {
        let yearWorkDays = activeSelectedYearWorkDays.filter { $0.type == .work }

        // Heures stockées dans les WorkDay
        let storedHours = yearWorkDays.reduce(0.0) { $0 + $1.totalHours }
        
        // Heures recalculées à partir des données brutes
        var recalculated = 0.0
        for workDay in yearWorkDays {
            if let start = workDay.startTime, let end = workDay.endTime {
                let worked = end.timeIntervalSince(start) - workDay.breakDuration
                recalculated += worked / 3600.0
            }
        }
        
        return HoursCheck(fromWorkDays: storedHours, recalculated: recalculated)
    }
    
    /// Détecte les entrées en double pour la même date
    private var duplicateEntries: [DuplicateGroup] {
        let yearWorkDays = activeSelectedYearWorkDays
        
        // Grouper par date et type (jour uniquement, sans l'heure)
        var grouped: [String: [WorkDay]] = [:]
        for workDay in yearWorkDays {
            let key = "\(Self.duplicateKeyFormatter.string(from: workDay.date)):\(workDay.type.rawValue)"
            grouped[key, default: []].append(workDay)
        }
        
        // Ne garder que les groupes avec plus d'une entrée
        let duplicates = grouped
            .filter { $0.value.count > 1 }
            .map { (key, entries) -> DuplicateGroup in
                let dateKey = key.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
                let displayDate = Self.duplicateKeyFormatter.date(from: dateKey) ?? Date()
                return DuplicateGroup(
                    dateString: Self.mediumDateFormatter.string(from: displayDate),
                    entries: entries.sorted { $0.createdAt < $1.createdAt }
                )
            }
            .sorted { $0.dateString < $1.dateString }
        
        return duplicates
    }
    
    // MARK: - Helper Views
    
    private func configurationRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    private func diagnosticRow(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
    
    private func calculationStep(_ label: String, value: Double, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("diagnostics.days.short2".localized(value))
                .foregroundStyle(color)
                .fontWeight(bold ? .bold : .regular)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        Self.mediumDateFormatter.string(from: date)
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh%02d", h, abs(m))
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        WorkTimeCalculations.formattedTimeInterval(Double(seconds))
    }
    
    private func formatTime(_ date: Date) -> String {
        Self.shortTimeFormatter.string(from: date)
    }
    
    private func recalculateAllHours() {
        let yearWorkDays = activeSelectedYearWorkDays
        let previousValues = Dictionary(uniqueKeysWithValues: yearWorkDays.map {
            ($0.id, ($0.totalHours, $0.overtimeSeconds))
        })
        
        var modifiedCount = 0
        var unchangedCount = 0
        var totalOvertimeBefore: Int = 0
        var totalOvertimeAfter: Int = 0
        
        for workDay in yearWorkDays {
            totalOvertimeBefore += workDay.overtimeSeconds
            
            // Recalculer les heures
            workDay.calculateHours()
        }

        _ = WorkDay.reconcileDailyOvertime(for: yearWorkDays)

        for workDay in yearWorkDays {
            totalOvertimeAfter += workDay.overtimeSeconds
            guard let previous = previousValues[workDay.id] else { continue }
            if workDay.overtimeSeconds != previous.1 || abs(workDay.totalHours - previous.0) > 0.001 {
                modifiedCount += 1
            } else {
                unchangedCount += 1
            }
        }
        
        // Sauvegarder les changements
        do {
            try modelContext.save()
            
            let beforeFormatted = formatSeconds(totalOvertimeBefore)
            let afterFormatted = formatSeconds(totalOvertimeAfter)
            let differenceSeconds = totalOvertimeAfter - totalOvertimeBefore
            let differenceFormatted = formatSeconds(differenceSeconds)
            
            recalculateResultMessage = "diagnostics.recalculate.result".localized(
                yearWorkDays.count, modifiedCount, unchangedCount,
                beforeFormatted, afterFormatted, differenceFormatted
            )
        } catch {
            recalculateResultMessage = "diagnostics.recalculate.saveError".localized(error.localizedDescription)
        }
        
        showingRecalculateResult = true
    }

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    private static let duplicateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func generateReport() {
        let day = "diagnostics.unit.dayShort".localized
        let rule = "═══════════════════════════════════════"
        var lines = [
            rule,
            "diagnostics.report.title".localized,
            "diagnostics.report.generatedOn".localized(formatDate(Date())),
            rule,
            "",
            "diagnostics.config.header".localized,
            "─────────────",
            "\("diagnostics.config.startDate".localized): \(formatDate(settings.vacationStartDate))",
            "\("diagnostics.vacation.initial".localized): \("diagnostics.days.decimal2".localized(settings.initialVacationDays))",
            "\("diagnostics.config.annual".localized): \("diagnostics.days.count".localized(settings.annualVacationDays))",
            "\("diagnostics.config.weeklyHours".localized): \(String(format: "%.1f", settings.weeklyHours))h",
            "\("diagnostics.config.dailyHours".localized): \(String(format: "%.2f", settings.standardDailyHours))h"
        ]

        // Ajouter les stats pour chaque année
        for entry in carryoverHistory {
            let startMark = entry.isStartYear ? " " + "diagnostics.report.startYear".localized : ""
            lines += ["", "diagnostics.report.year".localized(String(entry.year)) + startMark, "─────────────"]
            if entry.isStartYear {
                lines += [
                    "\("diagnostics.vacation.initial".localized): \(String(format: "%.2f", entry.carryIn)) \(day)",
                    "\("diagnostics.report.used".localized): \(String(format: "%.2f", entry.used)) \(day)",
                    "\("diagnostics.report.remaining".localized): \(String(format: "%.2f", entry.remaining)) \(day)"
                ]
            } else {
                lines += [
                    "\("diagnostics.vacation.carryIn".localized): \(String(format: "%.2f", entry.carryIn)) \(day)",
                    "\("diagnostics.vacation.entitlement".localized): \(String(format: "%.2f", entry.entitlement)) \(day)",
                    "\("diagnostics.vacation.used".localized): \(String(format: "%.2f", entry.used)) \(day)",
                    "\("diagnostics.vacation.remaining".localized): \(String(format: "%.2f", entry.remaining)) \(day)"
                ]
            }
        }

        lines += ["", "", rule, "diagnostics.report.end".localized, rule]

        diagnosticReport = lines.joined(separator: "\n")
        showingExportAlert = true
    }
}

// MARK: - Supporting Types

private struct YearStatistics {
    let totalEntries: Int
    let deletedEntries: Int
    let activeEntries: Int
    let workDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let vacationDays: Int
    let halfVacationDays: Int
    let totalVacationDays: Double
    let sickDays: Int
    let holidays: Int
    let compensatoryDays: Int
}

private struct VacationCalc {
    let isStartYear: Bool
    let carryIn: Double
    let annual: Double
    let used: Double
    let remaining: Double
}

private struct CarryoverEntry {
    let year: Int
    let isStartYear: Bool
    let carryIn: Double
    let entitlement: Double
    let used: Double
    let remaining: Double
}

private struct HoursCheck {
    let fromWorkDays: Double
    let recalculated: Double
}

private struct DuplicateGroup {
    let dateString: String
    let entries: [WorkDay]
}

// MARK: - Preview

#Preview {
    DiagnosticsView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}

