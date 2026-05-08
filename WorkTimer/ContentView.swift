import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab = 0
    
    var body: some View {
        mainTabView
            .tint(.blue)
            .onChange(of: selectedTab) { _, _ in
                // Rafraîchir le cache stats lors du changement d'onglet
                StatsCache.shared.invalidateAll()
            }
    }
    
    // MARK: - Tab View
    private var mainTabView: some View {
        modernTabView
            .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: - iOS 26 Tab API (native Liquid Glass tab styling)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("navigation.home".localized, systemImage: "house.fill", value: 0) {
                NavigationStack {
                    HomeTabView()
                }
            }
            .accessibilityHint("accessibility.home.hint".localized)

            Tab("navigation.workDays".localized, systemImage: "list.bullet", value: 1) {
                NavigationStack {
                    LazyView { WorkDaysListView() }
                }
            }
            .accessibilityHint("accessibility.workDays.hint".localized)

            Tab("navigation.calendar".localized, systemImage: "calendar", value: 2) {
                NavigationStack {
                    LazyView { CalendarView() }
                }
            }
            .accessibilityHint("accessibility.calendar.hint".localized)

            Tab("navigation.stats".localized, systemImage: "chart.bar.fill", value: 3) {
                NavigationStack {
                    LazyView { StatsView() }
                }
            }
            .accessibilityHint("accessibility.stats.hint".localized)

            Tab("navigation.settings".localized, systemImage: "gear", value: 4) {
                NavigationStack {
                    LazyView { SettingsView() }
                }
            }
            .accessibilityHint("accessibility.settings.hint".localized)
        }
    }
}

// MARK: - LazyView optimisé
/// Composant pour charger paresseusement les vues - vraiment paresseux cette fois
struct LazyView<Content: View>: View {
    @State private var hasAppeared = false
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if hasAppeared {
        content()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                // Vue de chargement élégante
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("loading".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
        .animation(DS.Animation.micro, value: hasAppeared)
        .onAppear {
            if !hasAppeared {
                // Petit délai pour laisser l'animation de tab s'effectuer
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    hasAppeared = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
