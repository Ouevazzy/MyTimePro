import Foundation
import Testing
@testable import WorkTimer

@Suite("Services background")
struct ModernAppDelegateTests {
    @Test("Les services CloudKit en arrière-plan suivent la configuration de build")
    func cloudBackgroundServicesFollowBuildConfiguration() {
        #if DEBUG
        #expect(!ModernAppDelegate.cloudBackgroundServicesEnabled)
        #else
        #expect(ModernAppDelegate.cloudBackgroundServicesEnabled)
        #endif
    }

    @Test("L'Info.plist ne déclare que les modes background réellement utilisés")
    func infoPlistDeclaresOnlyUsedBackgroundModes() throws {
        let modes = try #require(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])

        #expect(modes.contains("processing"))
        #expect(modes.contains("remote-notification"))
        #expect(!modes.contains("fetch"))
    }
}
