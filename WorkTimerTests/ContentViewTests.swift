import Testing
@testable import WorkTimer

@Suite("Navigation iOS 27")
struct ContentViewTests {
    @Test("Une sélection d'onglet persistée invalide revient à l'accueil")
    func invalidPersistedTabFallsBackToHome() {
        #expect(WorkTimerTab.restoredSelection(rawValue: nil) == .home)
        #expect(WorkTimerTab.restoredSelection(rawValue: -1) == .home)
        #expect(WorkTimerTab.restoredSelection(rawValue: 99) == .home)
    }

    @Test("Les sélections d'onglets valides sont conservées")
    func validPersistedTabIsPreserved() {
        #expect(WorkTimerTab.restoredSelection(rawValue: WorkTimerTab.home.rawValue) == .home)
        #expect(WorkTimerTab.restoredSelection(rawValue: WorkTimerTab.stats.rawValue) == .stats)
        #expect(WorkTimerTab.restoredSelection(rawValue: WorkTimerTab.settings.rawValue) == .settings)
    }
}
