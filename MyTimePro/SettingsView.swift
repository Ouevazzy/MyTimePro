import SwiftUI
import SwiftData

struct SettingsView: View {
    // ... Autres propriétés restent inchangées ...
    
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
            // ... Le contenu du sheet reste inchangé ...
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
    
    // ... Autres sections et propriétés de vue restent inchangées ...
    
    private func resetSettings() async {
        settings.resetToDefaults()
        do {
            try modelContext.save()
            // Synchronisation après réinitialisation
            await CloudService.shared.requestSync()
        } catch {
            print("Failed to save after reset: \(error)")
        }
    }
}

// ... Le reste du code reste inchangé ...