import SwiftUI
import CloudKit

enum ExportType: String, CaseIterable {
    case pdf = "PDF"
    case csv = "CSV"
}

struct SettingsView: View {
    @AppStorage("weeklyHours") private var weeklyHours: Double = 35
    @AppStorage("dailyHours") private var dailyHours: Double = 7
    @AppStorage("vacationDays") private var vacationDays: Double = 25
    @AppStorage("workingDays") private var workingDays: Set<Int> = Set(1...5)
    
    @State private var showingExportSheet = false
    @State private var selectedExportType: ExportType = .pdf
    @State private var iCloudStatus: String = ""
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            Form {
                cloudSection
                exportSection
                workSettingsSection
                aboutSection
                resetSection
            }
            .navigationTitle("Réglages")
            .onAppear {
                checkICloudStatus()
            }
        }
    }
    
    // Section Cloud
    private var cloudSection: some View {
        Section(header: Text("iCloud")) {
            Text("Statut: \(iCloudStatus)")
            Button("Synchroniser maintenant") {
                Task {
                    await syncWithICloud()
                }
            }
        }
    }
    
    // Section Export
    private var exportSection: some View {
        Section(header: Text("Export")) {
            Picker("Format", selection: $selectedExportType) {
                ForEach(ExportType.allCases, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            
            Button("Exporter le mois actuel") {
                exportCurrentMonth()
            }
            
            Button("Exporter l'année \(currentYear)") {
                exportCurrentYear()
            }
        }
    }
    
    // Section paramètres de travail
    private var workSettingsSection: some View {
        Section(header: Text("Paramètres de travail")) {
            weeklyHoursRow
            workingDaysToggles
            dailyHoursRow
            vacationDaysRow
        }
    }
    
    private var weeklyHoursRow: some View {
        NavigationLink(destination: WeeklyHoursPickerView(weeklyHours: $weeklyHours)) {
            HStack {
                Text("Heures hebdomadaires")
                Spacer()
                Text("\(weeklyHours, specifier: "%.1f")h")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var workingDaysToggles: some View {
        ForEach(1...7, id: \.self) { day in
            Toggle(calendar.weekdaySymbols[day-1], isOn: Binding(
                get: { workingDays.contains(day) },
                set: { isOn in
                    if isOn {
                        workingDays.insert(day)
                    } else {
                        workingDays.remove(day)
                    }
                }
            ))
        }
    }
    
    private var dailyHoursRow: some View {
        HStack {
            Text("Heures quotidiennes")
            Spacer()
            Text("\(dailyHours, specifier: "%.1f")h")
        }
    }
    
    private var vacationDaysRow: some View {
        HStack {
            Text("Jours de congés")
            Spacer()
            Text("\(vacationDays, specifier: "%.0f") jours")
        }
    }
    
    // Section À propos
    private var aboutSection: some View {
        Section(header: Text("À propos")) {
            Text("Version 1.0")
            Link("Site web", destination: URL(string: "https://mytimepro.app")!)
        }
    }
    
    // Section Réinitialisation
    private var resetSection: some View {
        Section {
            Button("Réinitialiser les paramètres", role: .destructive) {
                resetSettings()
            }
        }
    }
    
    // MARK: - Fonctions Cloud
    private func checkICloudStatus() {
        CKContainer.default().accountStatus { (accountStatus, error) in
            DispatchQueue.main.async {
                switch accountStatus {
                case .available:
                    self.iCloudStatus = "Disponible"
                case .noAccount:
                    self.iCloudStatus = "Pas de compte"
                case .restricted:
                    self.iCloudStatus = "Restreint"
                case .couldNotDetermine:
                    self.iCloudStatus = "Indéterminé"
                @unknown default:
                    self.iCloudStatus = "Inconnu"
                }
            }
        }
    }
    
    private func syncWithICloud() async {
        do {
            let settings = Settings(
                weeklyHours: weeklyHours,
                dailyHours: dailyHours,
                vacationDays: vacationDays,
                workingDays: workingDays
            )
            try await CloudKitManager.shared.saveSettings(settings)
        } catch {
            print("Erreur de synchronisation: \(error)")
        }
    }
    
    // MARK: - Utilitaires
    private var currentYear: Int {
        return Calendar.current.component(.year, from: Date())
    }
    
    private func monthName(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }
    
    private func exportCurrentMonth() {
        if selectedExportType == .pdf {
            generateAndSharePDF()
        } else {
            generateAndShareCSV()
        }
    }
    
    private func exportCurrentYear() {
        // Implémentation de l'export annuel à venir
    }
    
    private func generateAndSharePDF() {
        // Implémentation de la génération PDF à venir
    }
    
    private func generateAndShareCSV() {
        // Implémentation de la génération CSV à venir
    }
    
    private func resetSettings() {
        weeklyHours = 35
        dailyHours = 7
        vacationDays = 25
        workingDays = Set(1...5)
    }
}

struct WeeklyHoursPickerView: View {
    @Binding var weeklyHours: Double
    
    var body: some View {
        VStack {
            Slider(value: $weeklyHours, in: 0...60, step: 0.5)
            Text("\(weeklyHours, specifier: "%.1f") heures")
        }
        .padding()
    }
}