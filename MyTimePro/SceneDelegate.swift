import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contentView = ContentView()

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Task {
            do {
                if let settings = try await CloudKitManager.shared.fetchSettings() {
                    NotificationCenter.default.post(
                        name: .settingsDidChange,
                        object: settings
                    )
                }
            } catch {
                print("Error fetching settings: \(error)")
            }
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Task {
            do {
                let settings = Settings(
                    weeklyHours: UserDefaults.standard.double(forKey: "weeklyHours"),
                    dailyHours: UserDefaults.standard.double(forKey: "dailyHours"),
                    vacationDays: UserDefaults.standard.double(forKey: "vacationDays"),
                    workingDays: Set(UserDefaults.standard.array(forKey: "workingDays") as? [Int] ?? Array(1...5))
                )
                try await CloudKitManager.shared.saveSettings(settings)
            } catch {
                print("Error saving settings: \(error)")
            }
        }
    }
}
