import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedTab") private var selectedTab = AppTab.home.rawValue
    @State private var focusedCalendarDate: Date?

    var body: some View {
        mainTabView
            .tint(.blue)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .onChange(of: selectedTab) { _, newValue in
                if newValue == AppTab.stats.rawValue {
                    StatsCache.shared.invalidateAll()
                }
            }
            .onAppear(perform: handlePendingSiriAction)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    handlePendingSiriAction()
                }
            }
    }
    
    // MARK: - Tab View
    private var mainTabView: some View {
        modernTabView
    }

    // MARK: - iOS 26 Tab API (native Liquid Glass tab styling)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("navigation.home".localized, systemImage: "house.fill", value: AppTab.home.rawValue) {
                NavigationStack {
                    HomeTabView()
                }
            }
            .accessibilityHint("accessibility.home.hint".localized)

            Tab("navigation.workDays".localized, systemImage: "list.bullet", value: AppTab.workDays.rawValue) {
                NavigationStack {
                    WorkDaysListView()
                }
            }
            .accessibilityHint("accessibility.workDays.hint".localized)

            Tab("navigation.calendar".localized, systemImage: "calendar", value: AppTab.calendar.rawValue) {
                NavigationStack {
                    CalendarView(focusedDate: $focusedCalendarDate)
                }
            }
            .accessibilityHint("accessibility.calendar.hint".localized)

            Tab("navigation.stats".localized, systemImage: "chart.bar.fill", value: AppTab.stats.rawValue) {
                NavigationStack {
                    StatsView()
                }
            }
            .accessibilityHint("accessibility.stats.hint".localized)

            Tab("navigation.settings".localized, systemImage: "gear", value: AppTab.settings.rawValue) {
                NavigationStack {
                    SettingsView()
                }
            }
            .accessibilityHint("accessibility.settings.hint".localized)
        }
    }

    private enum AppTab: Int {
        case home = 0
        case workDays
        case calendar
        case stats
        case settings

        init(destination: WorkTimerDestinationIntentValue) {
            switch destination {
            case .home:
                self = .home
            case .workDays:
                self = .workDays
            case .calendar:
                self = .calendar
            case .stats:
                self = .stats
            case .settings:
                self = .settings
            }
        }
    }

    private func handlePendingSiriAction() {
        guard let action = SiriShortcutsHelper.shared.checkSiriActions() else { return }

        if case .openDestination(let destination) = action {
            selectedTab = AppTab(destination: destination).rawValue
            return
        }

        if case .openCalendarDate(let date) = action {
            focusedCalendarDate = Calendar.current.startOfDay(for: date)
            selectedTab = AppTab.calendar.rawValue
            return
        }

        do {
            try SiriActionProcessor(modelContext: modelContext).process(action)
            selectedTab = AppTab.calendar.rawValue
            Haptic.notification(.success)
        } catch {
            ErrorManager.shared.handle(error, context: "SiriAction")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
