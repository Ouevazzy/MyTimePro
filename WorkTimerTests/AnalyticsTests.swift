import Testing
@testable import WorkTimer

@Suite("Analytics")
@MainActor
struct AnalyticsTests {
    @Test("Les analytics restent désactivés par défaut")
    func analyticsStayDisabledByDefault() {
        Analytics.shared.setEnabled(false)
        let eventCount = Analytics.shared.exportEvents().count

        Analytics.shared.logScreenView("test_screen")

        #expect(Analytics.shared.exportEvents().count == eventCount)
    }
}
