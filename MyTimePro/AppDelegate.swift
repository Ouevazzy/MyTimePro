import UIKit
import CloudKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupCloudKit()
        registerForPushNotifications()
        return true
    }
    
    private func setupCloudKit() {
        let container = CKContainer(identifier: "iCloud.jordan-payez.MyTimePro")
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                switch accountStatus {
                case .available:
                    self?.fetchCloudKitData()
                case .noAccount:
                    print("No iCloud account available")
                case .restricted:
                    print("iCloud account restricted")
                case .couldNotDetermine:
                    print("Could not determine iCloud account status")
                @unknown default:
                    print("Unknown iCloud account status")
                }
            }
        }
    }
    
    private func fetchCloudKitData() {
        Task {
            do {
                if let settings = try await CloudKitManager.shared.fetchSettings() {
                    // Mettre à jour les UserDefaults avec les données de CloudKit
                    UserDefaults.standard.set(settings.weeklyHours, forKey: "weeklyHours")
                    UserDefaults.standard.set(settings.dailyHours, forKey: "dailyHours")
                    UserDefaults.standard.set(settings.vacationDays, forKey: "vacationDays")
                    UserDefaults.standard.set(Array(settings.workingDays), forKey: "workingDays")
                }
            } catch {
                print("Error fetching CloudKit data: \(error)")
            }
        }
    }
    
    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // MARK: - Push Notification Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for notifications: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let dict = userInfo as? [String: NSObject], let notification = CKNotification(fromRemoteNotificationDictionary: dict) {
            if notification.notificationType == .database {
                // Rafraîchir les données depuis CloudKit
                Task {
                    do {
                        await fetchCloudKitData()
                        completionHandler(.newData)
                    }
                }
            }
        } else {
            completionHandler(.noData)
        }
    }
}
