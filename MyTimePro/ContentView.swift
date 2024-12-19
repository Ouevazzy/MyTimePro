import SwiftUI
import CloudKit

struct ContentView: View {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var isRestoring = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        TabView {
            NavigationView {
                TimeRecordingView()
            }
            .tabItem {
                Label("Enregistrer", systemImage: "clock")
            }
            
            NavigationView {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiques", systemImage: "chart.bar")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Réglages", systemImage: "gear")
            }
        }
        .onAppear {
            checkAndRestoreData()
        }
        .alert("Message", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func checkAndRestoreData() {
        Task {
            do {
                if try await CloudKitManager.shared.shouldRestoreData() {
                    isRestoring = true
                    try await restoreData()
                    isRestoring = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func restoreData() async throws {
        guard let settings = try await CloudKitManager.shared.fetchSettings() else {
            return
        }
        
        await MainActor.run {
            UserDefaults.standard.set(settings.weeklyHours, forKey: "weeklyHours")
            UserDefaults.standard.set(settings.dailyHours, forKey: "dailyHours")
            UserDefaults.standard.set(settings.vacationDays, forKey: "vacationDays")
            UserDefaults.standard.set(Array(settings.workingDays), forKey: "workingDays")
            
            alertMessage = "Données restaurées avec succès"
            showingAlert = true
        }
    }
}
