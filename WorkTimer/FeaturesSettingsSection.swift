import SwiftUI
import SwiftData

struct FeaturesSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    private var store: StoreManager { StoreManager.shared }
    @Binding var activeSection: SettingsSection?

    @State private var showNotifications = false
    @State private var showCharts = false
    @State private var showSiriSettings = false
    @State private var showPaywall = false

    var body: some View {
        SettingsCard(
            title: "settings.features.title".localized, icon: "star.fill", color: .orange,
            isExpanded: activeSection == .features,
            onToggle: {
                withAnimation(DS.Animation.cardToggle) {
                    activeSection = activeSection == .features ? nil : .features
                }
            }
        ) {
            VStack(spacing: DS.Spacing.md) {
                FeatureButton(
                    title: "settings.notifications".localized,
                    subtitle: "settings.notifications.subtitle".localized,
                    icon: "bell.badge.fill", color: .red
                ) {
                    showNotifications = true
                }
                FeatureButton(
                    title: "settings.charts".localized,
                    subtitle: "settings.charts.subtitle".localized,
                    icon: "chart.bar.fill", color: .blue,
                    isPro: !store.isPro
                ) {
                    if store.isPro { showCharts = true } else { showPaywall = true }
                }
                FeatureButton(
                    title: "settings.siri".localized,
                    subtitle: "settings.siri.subtitle".localized,
                    icon: "mic.fill", color: .purple,
                    isPro: !store.isPro
                ) {
                    if store.isPro { showSiriSettings = true } else { showPaywall = true }
                }
            }
            .padding(.vertical, DS.Spacing.xs).padding(.horizontal)
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    FeaturesSettingsSection(activeSection: .constant(.features))
        .padding()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
