import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedTab") private var selectedTab = 0
    private let settings = UserSettings.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeTabView()
            }
            .tabItem {
                Label("Accueil", systemImage: "house.fill")
            }
            .tag(0)
            .id("home")
            
            NavigationStack {
                LazyView {
                    WorkDaysListView()
                }
            }
            .tabItem {
                Label("Journées", systemImage: "list.bullet")
            }
            .tag(1)
            .id("workdays")
            
            NavigationStack {
                LazyView {
                    CalendarView()
                }
            }
            .tabItem {
                Label("Calendrier", systemImage: "calendar")
            }
            .tag(2)
            .id("calendar")
            
            NavigationStack {
                LazyView {
                    StatsView()
                }
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .tag(3)
            .id("stats")
            
            NavigationStack {
                LazyView {
                    SettingsView()
                }
            }
            .tabItem {
                Label("Réglages", systemImage: "gear")
            }
            .tag(4)
            .id("settings")
        }
        .tint(.blue)
    }
}

// Composant pour charger paresseusement les vues
struct LazyView<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
