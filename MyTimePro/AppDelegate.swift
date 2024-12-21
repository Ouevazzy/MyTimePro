import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("📱 Application did finish launching")
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📱 Received remote notification")
        
        guard let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.failed)
            return
        }
        
        if cloudKitNotification.subscriptionID == "mytimepro-all-changes" || 
           cloudKitNotification.subscriptionID == "mytimepro-workday-changes" {
            CloudService.shared.requestSync()
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Registered for remote notifications with token")
    }
}