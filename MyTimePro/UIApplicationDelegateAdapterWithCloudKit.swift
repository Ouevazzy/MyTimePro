import SwiftUI
import CloudKit

class UIApplicationDelegateAdapterWithCloudKit: NSObject, UIApplicationDelegate {
    let appDelegate = AppDelegate()
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return appDelegate.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        appDelegate.application(application,
                               didReceiveRemoteNotification: userInfo,
                               fetchCompletionHandler: completionHandler)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        appDelegate.application(application,
                               didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        appDelegate.application(application,
                               didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
}