import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedTab") private var selectedTab = 0
    private let settings = UserSettings.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Vue Accueil
            NavigationStack {
                HomeTabView()
            }
            .tabItem {
                Label("Accueil", systemImage: "house.fill")
            }
            .tag(0)
            
            // Vue principale : Liste des journées
            NavigationStack {
                WorkDaysListView()
            }
            .tabItem {
                Label("Journées", systemImage: "list.bullet")
            }
            .tag(1)
            
            // Vue Calendrier
            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label("Calendrier", systemImage: "calendar")
            }
            .tag(2)
            
            // Vue statistiques
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .tag(3)
            
            // Vue paramètres
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Réglages", systemImage: "gear")
            }
            .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
