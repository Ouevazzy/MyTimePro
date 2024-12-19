import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = UserSettings.shared
    @StateObject private var cloudService = CloudService.shared
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]

    @State private var weeklyHours: Double = 41.0
    @State private var showingHoursPicker = false
    @State private var selectedHours: Double = 8.0
    @State private var showResetAlert = false
    @State private var showVacationDetails = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var exportType: ExportType?

    var body: some View {
        NavigationStack {
            Form {
                workTimeSection
                displaySection
                cloudSection
                exportSection
                aboutSection
                resetSection
            }
            .navigationTitle("Réglages")
        }
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
            NavigationStack {
                List {
                    if type == .annual {
                        Section {
                            Picker("Année", selection: $selectedYear) {
                                ForEach((2020...currentYear), id: \.self) { year in
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
                                    ForEach((2020...currentYear), id: \.self) { year in
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
                            exportType = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let data = pdfData {
                ShareSheet(items: [data])
            }
        }
        .alert("Réinitialiser les données", isPresented: $showResetAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Réinitialiser", role: .destructive) {
                Task {
                    await resetSettings()
                }
            }
        } message: {
            Text("Cette action réinitialisera tous les paramètres à leurs valeurs par défaut. Cette action est irréversible.")
        }
    }

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

    private var displaySection: some View {
        Section {
            Toggle("Format décimal", isOn: $settings.useDecimalHours)
        } header: {
            Text("AFFICHAGE")
        } footer: {
            Text("Le format décimal affiche les heures en nombres décimaux (ex: 8.5h au lieu de 8h30)")
        }
    }

    private func resetSettings() async {
        settings.resetToDefaults()
        do {
            try modelContext.save()
            await CloudService.shared.requestSync()
        } catch {
            print("Failed to save after reset: \(error)")
        }
    }

    private func saveWeeklyHours(_ newValue: Double) {
        settings.weeklyHours = newValue
        updateDailyHours()
    }

    private func updateDailyHours() {
        let workingDaysCount = settings.workingDays.filter { $0 }.count
        guard workingDaysCount > 0 else { return }
        settings.standardDailyHours = (settings.weeklyHours / Double(workingDaysCount)).rounded(to: 2)
    }
}