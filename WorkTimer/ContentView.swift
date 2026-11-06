import SwiftUI
import SwiftData

/// Une sélection typée empêche une valeur obsolète de `UserDefaults` de
/// référencer un onglet absent. C'est indispensable avec le SDK iOS 27 :
/// `TabView` exige désormais que sa sélection désigne un onglet visible.
enum WorkTimerTab: Int, CaseIterable {
    case home
    case workDays
    case calendar
    case stats
    case settings

    static func restoredSelection(rawValue: Int?) -> Self {
        guard let rawValue, let tab = Self(rawValue: rawValue) else {
            return .home
        }
        return tab
    }

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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: WorkTimerTab
    @State private var focusedCalendarDate: Date?

    init() {
        let storedValue = UserDefaults.standard.object(forKey: "selectedTab") as? Int
        let restoredTab = WorkTimerTab.restoredSelection(rawValue: storedValue)
        _selectedTab = State(initialValue: restoredTab)

        // Répare une valeur absente ou invalide dès le lancement, avant que
        // TabView n'évalue sa sélection.
        if storedValue != restoredTab.rawValue {
            UserDefaults.standard.set(restoredTab.rawValue, forKey: "selectedTab")
        }
    }

    var body: some View {
        mainTabView
            .tint(.blue)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .onChange(of: selectedTab) { _, newTab in
                UserDefaults.standard.set(newTab.rawValue, forKey: "selectedTab")
                if newTab == .stats {
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
            Tab("navigation.home".localized, systemImage: "house.fill", value: WorkTimerTab.home) {
                NavigationStack {
                    HomeTabView()
                }
            }
            .accessibilityHint("accessibility.home.hint".localized)

            Tab("navigation.workDays".localized, systemImage: "list.bullet", value: WorkTimerTab.workDays) {
                NavigationStack {
                    WorkDaysListView()
                }
            }
            .accessibilityHint("accessibility.workDays.hint".localized)

            Tab("navigation.calendar".localized, systemImage: "calendar", value: WorkTimerTab.calendar) {
                NavigationStack {
                    CalendarView(focusedDate: $focusedCalendarDate)
                }
            }
            .accessibilityHint("accessibility.calendar.hint".localized)

            Tab("navigation.stats".localized, systemImage: "chart.bar.fill", value: WorkTimerTab.stats) {
                NavigationStack {
                    StatsView()
                }
            }
            .accessibilityHint("accessibility.stats.hint".localized)

            Tab("navigation.settings".localized, systemImage: "gear", value: WorkTimerTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .accessibilityHint("accessibility.settings.hint".localized)
        }
    }

    private func handlePendingSiriAction() {
        guard let action = SiriShortcutsHelper.shared.checkSiriActions() else { return }

        if case .startTimer(let date) = action {
            if !TimerManager.shared.isActive {
                TimerManager.shared.start(at: date)
            }
            selectedTab = .home
            Haptic.notification(.success)
            return
        }

        if case .stopTimer(let date) = action {
            selectedTab = .home
            if TimerManager.shared.isActive {
                let outcome = TimerManager.shared.stopAndSave(in: modelContext, at: date)
                if outcome.result == .saved { Haptic.notification(.success) }
            } else {
                // Aucune session en cours : repli sur la saisie d'un départ manuel.
                do {
                    try SiriActionProcessor(modelContext: modelContext)
                        .process(.updateEntry(departureTime: date))
                    Haptic.notification(.success)
                } catch {
                    ErrorManager.shared.handle(error, context: "SiriAction")
                }
            }
            return
        }

        if case .openDestination(let destination) = action {
            selectedTab = WorkTimerTab(destination: destination)
            return
        }

        if case .openCalendarDate(let date) = action {
            focusedCalendarDate = Calendar.current.startOfDay(for: date)
            selectedTab = .calendar
            return
        }

        do {
            try SiriActionProcessor(modelContext: modelContext).process(action)
            selectedTab = .calendar
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
