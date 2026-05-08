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
                    configurationRow("Date de début", value: formatDate(settings.vacationStartDate))
                    configurationRow("Solde initial", value: String(format: "%.2f jours", settings.initialVacationDays))
                    configurationRow("Droits annuels", value: "\(settings.annualVacationDays) jours")
                    configurationRow("Heures/semaine", value: String(format: "%.1f h", settings.weeklyHours))
                    configurationRow("Heures/jour", value: String(format: "%.2f h", settings.standardDailyHours))
                } header: {
                    Label("CONFIGURATION", systemImage: "gearshape")
                }
                
                // Section Sélection d'année
                Section {
                    Picker("Année", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("SÉLECTION", systemImage: "calendar")
                }
                
                // Section Statistiques de l'année
                Section {
                    let stats = yearStats
                    
                    diagnosticRow("Entrées totales", value: "\(stats.totalEntries)", icon: "doc.text", color: .blue)
                    diagnosticRow("Entrées supprimées", value: "\(stats.deletedEntries)", icon: "trash", color: .red)
                    diagnosticRow("Entrées actives", value: "\(stats.activeEntries)", icon: "checkmark.circle", color: .green)
                    
                    Divider()
                    
                    diagnosticRow("Jours travaillés", value: "\(stats.workDays)", icon: "briefcase", color: .blue)
                    diagnosticRow("Heures totales", value: formatHours(stats.totalHours), icon: "clock", color: .blue)
                    diagnosticRow("Heures supp.", value: formatSeconds(stats.overtimeSeconds), icon: "clock.badge.exclamationmark", color: stats.overtimeSeconds >= 0 ? .green : .red)
                    
                    Divider()
                    
                    diagnosticRow("Congés complets", value: "\(stats.vacationDays)", icon: "sun.max", color: .orange)
                    diagnosticRow("Demi-journées", value: "\(stats.halfVacationDays)", icon: "sun.min", color: .orange)
                    diagnosticRow("Total congés", value: String(format: "%.1f j", stats.totalVacationDays), icon: "sun.max.fill", color: .orange)
                    diagnosticRow("Jours maladie", value: "\(stats.sickDays)", icon: "cross.case", color: .red)
                    diagnosticRow("Jours fériés", value: "\(stats.holidays)", icon: "star", color: .yellow)
                    diagnosticRow("J. compensatoires", value: "\(stats.compensatoryDays)", icon: "arrow.2.squarepath", color: .green)
                    
                } header: {
                    Label("STATISTIQUES \(selectedYear)", systemImage: "chart.bar")
                }
                
                // Section Calcul des congés détaillé
                Section {
                    let vacationCalc = vacationCalculation
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calcul du solde de congés")
                            .font(.headline)
                        
                        if vacationCalc.isStartYear {
                            calculationStep("Solde initial", value: vacationCalc.carryIn, color: .purple)
                            calculationStep("- Utilisés", value: -vacationCalc.used, color: .orange)
                            Divider()
                            calculationStep("= Restant", value: vacationCalc.remaining, color: vacationCalc.remaining > 0 ? .green : .red, bold: true)
                        } else {
                            calculationStep("Report entrant", value: vacationCalc.carryIn, color: .purple)
                            calculationStep("+ Droits annuels", value: vacationCalc.annual, color: .blue)
                            calculationStep("- Utilisés", value: -vacationCalc.used, color: .orange)
                            Divider()
                            calculationStep("= Restant", value: vacationCalc.remaining, color: vacationCalc.remaining > 0 ? .green : .red, bold: true)
                        }
                    }
                    .padding(.vertical, 8)
                    
                } header: {
                    Label("CALCUL CONGÉS \(selectedYear)", systemImage: "function")
                }
                
                // Section Détail du report par année
                Section {
                    ForEach(carryoverHistory, id: \.year) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(entry.year)")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1f j restants", entry.remaining))
                                    .foregroundColor(entry.remaining > 0 ? .green : .red)
                            }
                            
                            HStack {
                                if entry.isStartYear {
                                    Text("Initial: \(String(format: "%.1f", entry.carryIn))")
                                } else {
                                    Text("Report: \(String(format: "%.1f", entry.carryIn)) + Droits: \(String(format: "%.1f", entry.entitlement))")
                                }
                                Text("- Utilisés: \(String(format: "%.1f", entry.used))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("HISTORIQUE DES REPORTS", systemImage: "clock.arrow.circlepath")
                }
                
                // Section Vérification des heures
                Section {
                    let hoursCheck = hoursVerification
                    
                    diagnosticRow("Heures calculées (WorkDay)", value: formatHours(hoursCheck.fromWorkDays), icon: "doc.text", color: .blue)
                    diagnosticRow("Heures recalculées", value: formatHours(hoursCheck.recalculated), icon: "arrow.triangle.2.circlepath", color: .blue)
                    
                    let difference = abs(hoursCheck.fromWorkDays - hoursCheck.recalculated)
                    let isMatching = difference < 0.01
                    
                    HStack {
                        Image(systemName: isMatching ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isMatching ? .green : .orange)
                        Text(isMatching ? "Les calculs correspondent ✓" : "Différence: \(formatHours(difference))")
                            .foregroundColor(isMatching ? .green : .orange)
                    }
                    
                } header: {
                    Label("VÉRIFICATION HEURES", systemImage: "checkmark.shield")
                }
                
                // Section Détection des doublons
                Section {
                    let duplicates = duplicateEntries
                    
                    if duplicates.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Aucun doublon détecté ✓")
                                .foregroundColor(.green)
                        }
                    } else {
                        diagnosticRow("Dates avec doublons", value: "\(duplicates.count)", icon: "exclamationmark.triangle.fill", color: .orange)
                        diagnosticRow("Entrées en double", value: "\(duplicates.reduce(0) { $0 + $1.entries.count })", icon: "doc.on.doc", color: .orange)
                        
                        ForEach(duplicates, id: \.dateString) { duplicate in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundColor(.orange)
                                    Text(duplicate.dateString)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(duplicate.entries.count) entrées")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                
                                ForEach(duplicate.entries, id: \.id) { entry in
                                    HStack {
                                        Text("• \(entry.type.displayName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if entry.type.isWorkDay, let start = entry.startTime, let end = entry.endTime {
                                            Text("\(formatTime(start)) - \(formatTime(end))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
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
                    Label("DÉTECTION DOUBLONS \(selectedYear)", systemImage: "doc.on.doc")
                }
                
                // Section Outils de correction
                Section {
                    Button(action: { showingRecalculateAlert = true }) {
                        Label("Recalculer toutes les heures (\(selectedYear))", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .foregroundColor(.orange)
                    
                    Text("Recalcule les heures travaillées et supplémentaires de chaque entrée en fonction des paramètres actuels.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Label("OUTILS DE CORRECTION", systemImage: "wrench.and.screwdriver")
                }
                
                // Bouton d'export
                Section {
                    Button(action: generateReport) {
                        Label("Générer rapport de diagnostic", systemImage: "doc.badge.gearshape")
                    }
                } header: {
                    Label("EXPORT", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Rapport généré", isPresented: $showingExportAlert) {
                Button("OK", role: .cancel) { }
                Button("Copier") {
                    UIPasteboard.general.string = diagnosticReport
                }
            } message: {
                Text("Le rapport a été généré. Voulez-vous le copier dans le presse-papiers ?")
            }
            .alert("Recalculer les heures", isPresented: $showingRecalculateAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Recalculer", role: .destructive) {
                    recalculateAllHours()
                }
            } message: {
                Text("Cette action va recalculer les heures travaillées et supplémentaires de toutes les entrées de \(selectedYear) en fonction de vos paramètres actuels.\n\nCette action est irréversible.")
            }
            .alert("Recalcul terminé", isPresented: $showingRecalculateResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(recalculateResultMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var yearStats: YearStatistics {
        let calendar = Calendar.current
        
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
        
        let activeWorkDays = yearWorkDays
        
        return YearStatistics(
            totalEntries: yearWorkDays.count,
            deletedEntries: 0,
            activeEntries: activeWorkDays.count,
            workDays: activeWorkDays.filter { $0.type == .work }.count,
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
        let calendar = Calendar.current
        
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear &&
            $0.type == .work
        }

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
        let calendar = Calendar.current
        
        // Filtrer par année sélectionnée
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
        
        // Grouper par date et type (jour uniquement, sans l'heure)
        var grouped: [String: [WorkDay]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for workDay in yearWorkDays {
            let key = "\(dateFormatter.string(from: workDay.date)):\(workDay.type.rawValue)"
            grouped[key, default: []].append(workDay)
        }
        
        // Ne garder que les groupes avec plus d'une entrée
        let duplicates = grouped
            .filter { $0.value.count > 1 }
            .map { (key, entries) -> DuplicateGroup in
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.locale = Locale(identifier: "fr_FR")
                let displayDate = dateFormatter.date(from: key) ?? Date()
                return DuplicateGroup(
                    dateString: displayFormatter.string(from: displayDate),
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
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    private func diagnosticRow(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    private func calculationStep(_ label: String, value: Double, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.2f j", value))
                .foregroundColor(color)
                .fontWeight(bold ? .bold : .regular)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
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
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    private func recalculateAllHours() {
        let calendar = Calendar.current
        
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
        
        var modifiedCount = 0
        var unchangedCount = 0
        var totalOvertimeBefore: Int = 0
        var totalOvertimeAfter: Int = 0
        
        for workDay in yearWorkDays {
            let oldOvertime = workDay.overtimeSeconds
            let oldTotalHours = workDay.totalHours
            totalOvertimeBefore += oldOvertime
            
            // Recalculer les heures
            workDay.calculateHours()
            
            totalOvertimeAfter += workDay.overtimeSeconds
            
            // Vérifier si quelque chose a changé
            if workDay.overtimeSeconds != oldOvertime || abs(workDay.totalHours - oldTotalHours) > 0.001 {
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
            
            recalculateResultMessage = """
            \(yearWorkDays.count) entrées traitées
            • \(modifiedCount) modifiées
            • \(unchangedCount) inchangées
            
            Heures supp. avant: \(beforeFormatted)
            Heures supp. après: \(afterFormatted)
            Différence: \(differenceFormatted)
            """
        } catch {
            recalculateResultMessage = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
        }
        
        showingRecalculateResult = true
    }
    
    private func generateReport() {
        var report = """
        ═══════════════════════════════════════
        RAPPORT DE DIAGNOSTIC WORKTIMER
        Généré le: \(formatDate(Date()))
        ═══════════════════════════════════════
        
        CONFIGURATION
        ─────────────
        Date de début: \(formatDate(settings.vacationStartDate))
        Solde initial: \(String(format: "%.2f", settings.initialVacationDays)) jours
        Droits annuels: \(settings.annualVacationDays) jours
        Heures/semaine: \(String(format: "%.1f", settings.weeklyHours))h
        Heures/jour: \(String(format: "%.2f", settings.standardDailyHours))h
        
        """
        
        // Ajouter les stats pour chaque année
        for entry in carryoverHistory {
            report += """
            
            ANNÉE \(entry.year) \(entry.isStartYear ? "(DÉBUT)" : "")
            ─────────────
            """
            
            if entry.isStartYear {
                report += """
                
                Solde initial: \(String(format: "%.2f", entry.carryIn)) j
                Utilisés: \(String(format: "%.2f", entry.used)) j
                Restant: \(String(format: "%.2f", entry.remaining)) j
                """
            } else {
                report += """
                
                Report entrant: \(String(format: "%.2f", entry.carryIn)) j
                + Droits annuels: \(String(format: "%.2f", entry.entitlement)) j
                - Utilisés: \(String(format: "%.2f", entry.used)) j
                = Restant: \(String(format: "%.2f", entry.remaining)) j
                """
            }
        }
        
        report += """
        
        
        ═══════════════════════════════════════
        FIN DU RAPPORT
        ═══════════════════════════════════════
        """
        
        diagnosticReport = report
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






