import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cloudService = CloudService.shared
    @State private var showingSyncError = false
    @State private var errorMessage = ""
    
    var body: some View {
        TabView {
            HomeTabView()
                .tabItem {
                    Label("Accueil", systemImage: "house")
                }
            
            WorkDaysListView()
                .tabItem {
                    Label("Historique", systemImage: "clock")
                }
            
            StatsView()
                .tabItem {
                    Label("Statistiques", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Paramètres", systemImage: "gear")
                }
        }
        .task {
            await syncData()
        }
        .alert("Erreur de synchronisation", isPresented: $showingSyncError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func syncData() async {
        do {
            try await cloudService.syncWithCloud(context: modelContext)
        } catch {
            showingSyncError = true
            errorMessage = error.localizedDescription
        }
    }
}
