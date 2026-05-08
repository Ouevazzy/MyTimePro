import SwiftUI
import SwiftData

struct FeaturesSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var activeSection: SettingsSection?

    @State private var showNotifications = false
    @State private var showCharts = false
    @State private var showSiriSettings = false

    var body: some View {
        SettingsCard(
            title: "settings.features.title".localized, icon: "star.fill", color: .orange,
            isExpanded: activeSection == .features,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .features ? nil : .features
                }
            }
        ) {
            VStack(spacing: DS.Spacing.md) {
                FeatureButton(title: "Notifications", subtitle: "Rappels de pointage",
                              icon: "bell.badge.fill", color: .red) {
                    showNotifications = true
                }
                FeatureButton(title: "Graphiques", subtitle: "Visualiser vos heures",
                              icon: "chart.bar.fill", color: .blue) {
                    showCharts = true
                }
                FeatureButton(title: "Raccourcis Siri", subtitle: "Contrôle vocal",
                              icon: "mic.fill", color: .purple) {
                    showSiriSettings = true
                }
            }
            .padding(.vertical, 5).padding(.horizontal)
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack { NotificationSettingsView() }
        }
        .sheet(isPresented: $showCharts) {
            NavigationStack {
                ChartsView().environment(\.modelContext, modelContext)
            }
        }
        .sheet(isPresented: $showSiriSettings) {
            NavigationStack { SiriSettingsView() }
        }
    }
}

#Preview {
    FeaturesSettingsSection(activeSection: .constant(.features))
        .padding()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
