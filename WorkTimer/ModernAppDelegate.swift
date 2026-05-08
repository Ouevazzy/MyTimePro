import UIKit
import CloudKit
import BackgroundTasks

class ModernAppDelegate: NSObject, UIApplicationDelegate {

    private static let syncTaskID = "com.mytiempo.sync"
    private static let cleanupTaskID = "com.mytiempo.cleanup"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        registerBackgroundTasks()
        setupPushNotifications()
        checkFirstInstall()
        return true
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncTaskID,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleSyncTask(task: processingTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.cleanupTaskID,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleCleanupTask(task: processingTask)
        }

        AppLogger.info("Background tasks registered", category: AppLogger.general)
    }

    func scheduleBackgroundTasks() {
        let syncRequest = BGProcessingTaskRequest(identifier: Self.syncTaskID)
        syncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        syncRequest.requiresNetworkConnectivity = true

        let cleanupRequest = BGProcessingTaskRequest(identifier: Self.cleanupTaskID)
        cleanupRequest.earliestBeginDate = Date(timeIntervalSinceNow: 86400)
        cleanupRequest.requiresNetworkConnectivity = true

        do {
            try BGTaskScheduler.shared.submit(syncRequest)
            try BGTaskScheduler.shared.submit(cleanupRequest)
            AppLogger.info("Background tasks scheduled", category: AppLogger.general)
        } catch {
            AppLogger.error("Failed to schedule background tasks", category: AppLogger.general, error: error)
        }
    }

    private func handleSyncTask(task: BGProcessingTask) {
        let syncTask = Task {
            do {
                try await ModernCloudService.shared.sendChanges()
                task.setTaskCompleted(success: true)
                AppLogger.info("Background sync completed", category: AppLogger.cloudKit)
                scheduleBackgroundTasks()
            } catch {
                AppLogger.error("Background sync failed", category: AppLogger.cloudKit, error: error)
                task.setTaskCompleted(success: false)
                scheduleBackgroundTasks()
            }
        }

        task.expirationHandler = { [weak self] in
            syncTask.cancel()
            task.setTaskCompleted(success: false)
            self?.scheduleBackgroundTasks()
        }
    }

    private func handleCleanupTask(task: BGProcessingTask) {
        let cleanupTask = Task {
            do {
                try await ModernCloudService.shared.sendChanges()
                task.setTaskCompleted(success: true)
                AppLogger.info("Background cleanup completed", category: AppLogger.cloudKit)
                scheduleBackgroundTasks()
            } catch {
                AppLogger.error("Background cleanup failed", category: AppLogger.cloudKit, error: error)
                task.setTaskCompleted(success: false)
                scheduleBackgroundTasks()
            }
        }

        task.expirationHandler = { [weak self] in
            cleanupTask.cancel()
            task.setTaskCompleted(success: false)
            self?.scheduleBackgroundTasks()
        }
    }

    // MARK: - Setup

    private func setupPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func checkFirstInstall() {
        let keychain = KeychainHelper.shared
        let isFirstInstall = keychain.retrieve(for: "isFirstInstall") == nil

        if isFirstInstall {
            keychain.save("true", for: "isFirstInstall")
            UserDefaults.standard.set(false, forKey: "hasCompletedFirstSync")
        }
    }

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.error("Failed to register for remote notifications", category: AppLogger.general, error: error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        if notification?.subscriptionID == "sync-changes" {
            Task {
                do {
                    try await ModernCloudService.shared.sendChanges()
                    completionHandler(.newData)
                } catch {
                    AppLogger.error("Remote notification sync failed", category: AppLogger.cloudKit, error: error)
                    completionHandler(.failed)
                }
            }
        } else {
            completionHandler(.noData)
        }
    }
}
