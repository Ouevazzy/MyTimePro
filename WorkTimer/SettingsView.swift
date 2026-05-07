import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = UserSettings.shared
    @State private var cloudService = CloudService.shared
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    
    // MARK: - State Properties
    @State private var weeklyHours: Double = 41.0
    @State private var showingHoursPicker = false
    @State private var selectedHours: Double = 8.0
    @State private var showResetAlert = false
    @State private var showVacationDetails = false
    @State private var showRestoreAlert = false
    
    // MARK: - Export Properties
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var exportType: ExportType?
    
    // MARK: - Constants
    private let weekDays = [
        "Lundi", "Mardi", "Mercredi", "Jeudi",
        "Vendredi", "Samedi", "Dimanche"
    ]
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    // MARK: - Computed Properties
    private var calculatedDailyHours: Double {
        let workingDaysCount = settings.workingDays.filter { $0 }.count
        guard workingDaysCount > 0 else { return 0 }
        return (settings.weeklyHours / Double(workingDaysCount)).rounded(to: 2)
    }
    
    private var yearlyVacationStats: (used: Double, remaining: Double) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let thisYearWorkDays = workDays.filter {
            Calendar.current.component(.year, from: $0.date) == currentYear
        }
        
        let vacationDays = thisYearWorkDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        
        return (
            used: vacationDays,
            remaining: Double(settings.annualVacationDays) - vacationDays
        )
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                workTimeSection
                displaySection
                exportSection
                aboutSection
                resetSection
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showingHoursPicker) {
                NavigationStack {
                    WeeklyHoursPickerView(
                        hours: $weeklyHours,
                        isPresented: $showingHoursPicker,
                        onSave: saveWeeklyHours
                    )
                }
            }
            .sheet(isPresented: $showVacationDetails) {
                VacationsView()
            }
            .sheet(item: $exportType) { type in
                ExportView(type: type, selectedYear: $selectedYear, selectedMonth: $selectedMonth)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
            .alert("Réinitialiser les données", isPresented: $showResetAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Réinitialiser", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("Cette action réinitialisera tous les paramètres à leurs valeurs par défaut. Cette action est irréversible.")
            }
            .alert("Restaurer depuis iCloud ?", isPresented: $showRestoreAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Restaurer", role: .destructive) {
                    Task {
                        await cloudService.restoreFromCloud()
                    }
                }
            } message: {
                Text("Cette action va télécharger toutes les données disponibles sur iCloud. Les données existantes seront fusionnées avec celles d'iCloud.")
            }
        }
    }
    
    // MARK: - Sections
    private var workTimeSection: some View {
        Section {
            weeklyHoursRow
            workingDaysToggles
            dailyHoursRow
            vacationDaysRow
        } header: {
            Text("HORAIRES DE TRAVAIL")
        } footer: {
            Text("Les heures par jour sont automatiquement calculées en fonction des heures hebdomadaires et des jours travaillés")
        }
    }
    
    private var weeklyHoursRow: some View {
        HStack {
            Text("Heures par semaine")
            Spacer()
            Button(action: {
                weeklyHours = settings.weeklyHours
                showingHoursPicker = true
            }) {
                Text("\(settings.weeklyHours, specifier: "%.1f")h")
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var workingDaysToggles: some View {
        ForEach(weekDays.indices, id: \.self) { index in
            Toggle(weekDays[index], isOn: $settings.workingDays[index])
                .onChange(of: settings.workingDays[index]) { _, _ in
                    updateDailyHours()
                }
        }
    }
    
    private var dailyHoursRow: some View {
        HStack {
            Text("Heures par jour")
            Spacer()
            Text("\(calculatedDailyHours, specifier: "%.2f")h")
                .foregroundColor(.secondary)
        }
    }
    
    private var vacationDaysRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Stepper(value: $settings.annualVacationDays, in: 0...50) {
                HStack {
                    Text("Jours de congé annuels")
                    Spacer()
                    Text("\(settings.annualVacationDays) jours")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { showVacationDetails = true }) {
                HStack(spacing: 8) {
                    Label(
                        String(format: "%.1f jours restants", yearlyVacationStats.remaining),
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var displaySection: some View {
        Section {
            Toggle("Format décimal", isOn: $settings.useDecimalHours)
        } header: {
            Text("AFFICHAGE")
        } footer: {
            Text("Le format décimal affiche les heures en nombres décimaux (ex: 8.5h au lieu de 8h30)")
        }
    }
    
  
    
    private var exportSection: some View {
        Section {
            Button(action: {
                exportType = .monthly
            }) {
                Label("Export mensuel", systemImage: "doc.text")
            }
            
            Button(action: {
                exportType = .annual
            }) {
                Label("Export annuel", systemImage: "doc.text.fill")
            }
        } header: {
            Text("EXPORT")
        } footer: {
            Text("Exportez vos données en PDF pour un mois ou une année complète.")
        }
    }
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersionString)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("À PROPOS")
        }
    }
    
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Réinitialiser les données")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateDailyHours() {
        settings.standardDailyHours = calculatedDailyHours
    }
    
    private func saveWeeklyHours(_ newValue: Double) {
        settings.weeklyHours = newValue
        updateDailyHours()
    }
}

// MARK: - Export View
struct ExportView: View {
    let type: ExportType
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            if type == .annual {
                Section {
                    Picker("Année", selection: $selectedYear) {
                        ForEach((2020...Calendar.current.component(.year, from: Date())), id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            } else {
                Section {
                    HStack {
                        Picker("Mois", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(month: month)).tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        Picker("Année", selection: $selectedYear) {
                            ForEach((2020...Calendar.current.component(.year, from: Date())), id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Section {
                Button(action: generateAndSharePDF) {
                    HStack {
                        Spacer()
                        Label("Générer le PDF", systemImage: "doc.badge.arrow.up")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(type == .annual ? "Export annuel" : "Export mensuel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Fermer") {
                    dismiss()
                }
            }
        }
    }
    
    private func monthName(month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.monthSymbols[month - 1].capitalized
    }
    
    private func generateAndSharePDF() {
        // Implémenter la génération du PDF
    }
}

// MARK: - Supporting Types
enum ExportType: Identifiable {
    case monthly
    case annual
    
    var id: Int {
        switch self {
        case .monthly: return 1
        case .annual: return 2
        }
    }
}

// MARK: - Helper Views
struct WeeklyHoursPickerView: View {
    @Binding var hours: Double
    @Binding var isPresented: Bool
    let onSave: (Double) -> Void
    
    var body: some View {
        Form {
            Stepper(value: $hours, in: 0...80, step: 0.5) {
                HStack {
                    Text("Heures par semaine")
                                        Spacer()
                                        Text("\(hours, specifier: "%.1f")h")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .navigationTitle("Heures hebdomadaires")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Annuler") {
                                        isPresented = false
                                    }
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Enregistrer") {
                                        onSave(hours)
                                        isPresented = false
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Extensions
                    extension Double {
                        func rounded(to places: Int) -> Double {
                            let divisor = pow(10.0, Double(places))
                            return (self * divisor).rounded() / divisor
                        }
                    }

                    extension Bundle {
                        var appVersionString: String {
                            let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
                            return "\(version) (\(build))"
                        }
                    }

                    // MARK: - Preview
                    #Preview {
                        NavigationStack {
                            SettingsView()
                                .modelContainer(for: WorkDay.self, inMemory: true)
                        }
                    }
