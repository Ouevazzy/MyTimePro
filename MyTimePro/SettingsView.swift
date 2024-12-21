import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userSettings = UserSettings.shared
    
    @Query private var workDays: [WorkDay]
    
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showingExportView = false
    
    var exportFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            else { return nil }
        return documentsDirectory.appendingPathComponent("rapport.pdf")
    }
    
    var body: some View {
        List {
            Section("Heures de travail journalières") {
                HStack {
                    TextField("7.4", value: $userSettings.standardDailyHours, format: .number)
                        .keyboardType(.decimalPad)
                    Text("heures")
                }
            }
            
            Section("Jours de travail") {
                Toggle("Lundi", isOn: $userSettings.mondayEnabled)
                Toggle("Mardi", isOn: $userSettings.tuesdayEnabled)
                Toggle("Mercredi", isOn: $userSettings.wednesdayEnabled)
                Toggle("Jeudi", isOn: $userSettings.thursdayEnabled)
                Toggle("Vendredi", isOn: $userSettings.fridayEnabled)
                Toggle("Samedi", isOn: $userSettings.saturdayEnabled)
                Toggle("Dimanche", isOn: $userSettings.sundayEnabled)
            }
            
            Section {
                Toggle("Format décimal", isOn: $userSettings.useDecimalHours)
            } header: {
                Text("Affichage")
            } footer: {
                Text("Format décimal : 7.50 heures au lieu de 7h30")
            }
            
            Section("Congés") {
                HStack {
                    TextField("25", value: $userSettings.annualVacationDays, format: .number)
                        .keyboardType(.decimalPad)
                    Text("jours par an")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Supprimer les données", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                
                Button(role: .destructive) {
                    showingDeleteAllConfirmation = true
                } label: {
                    Label("Tout supprimer", systemImage: "trash.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Paramètres")
        .alert("Confirmation", isPresented: $showingDeleteConfirmation, actions: {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                try? modelContext.delete(model: WorkDay.self)
                dismiss()
            }
        }, message: {
            Text("Êtes-vous sûr de vouloir supprimer toutes les données de l'application ? Cette action est irréversible.")
        })
        .alert("Suppression des données", isPresented: $showingDeleteAllConfirmation, actions: {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                try? modelContext.delete(model: WorkDay.self)
                // Reset user settings to default values
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                UserDefaults.standard.synchronize()
                dismiss()
            }
        }, message: {
            Text("Attention, cette action est irréversible et supprimera toutes les données, y compris vos paramètres.")
        })
    }
}
