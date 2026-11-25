import UIKit
import CloudKit
import BackgroundTasks
import os.log

/// Garantit que BGTaskScheduler ne reçoit qu'une seule complétion, même si
/// l'expiration arrive pendant que l'opération asynchrone se termine.
private final class BackgroundTaskFinisher: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false

    func finish(_ task: BGTask, success: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return false }
        didFinish = true
        task.setTaskCompleted(success: success)
        return true
    }
}

/// Sursis demandé à iOS, rendu une seule fois.
@MainActor
private final class BackgroundActivity {
    private var id = UIBackgroundTaskIdentifier.invalid

    func begin() {
        id = UIApplication.shared.beginBackgroundTask { [weak self] in self?.end() }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

class ModernAppDelegate: NSObject, UIApplicationDelegate {

    private static let syncTaskID = "com.mytiempo.sync"
    private static let cleanupTaskID = "com.mytiempo.cleanup"
    static var cloudBackgroundServicesEnabled: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        registerBackgroundTasks()
        setupPushNotifications()
        checkFirstInstall()
        return true
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        let syncRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncTaskID,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleSyncTask(task: processingTask)
        }

        let cleanupRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.cleanupTaskID,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleCleanupTask(task: processingTask)
        }

        AppLogger.info(
            "Background tasks registered sync=\(syncRegistered) cleanup=\(cleanupRegistered)",
            category: AppLogger.general
        )
    }

    func scheduleBackgroundTasks() {
        scheduleCleanupTask()

        guard Self.cloudBackgroundServicesEnabled else {
            AppLogger.debug("Background CloudKit sync disabled in DEBUG", category: AppLogger.cloudKit)
            return
        }

        scheduleSyncTask()
    }

    private func scheduleSyncTask() {
        let syncRequest = BGProcessingTaskRequest(identifier: Self.syncTaskID)
        syncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        syncRequest.requiresNetworkConnectivity = true

        submit(syncRequest, name: "sync", category: AppLogger.cloudKit)
    }

    /// La demande est asynchrone : on demande à iOS de ne pas suspendre l'app avant sa fin.
    private func submit(_ request: BGProcessingTaskRequest, name: String, category: OSLog) {
        Task { @MainActor in
            let activity = BackgroundActivity()
            activity.begin()
            do {
                try await BGTaskScheduler.shared.submitTaskRequest(request)
                AppLogger.info("Background \(name) task scheduled", category: category)
            } catch {
                AppLogger.error("Failed to schedule background \(name) task", category: category, error: error)
            }
            activity.end()
        }
    }

    private func scheduleCleanupTask() {
        let cleanupRequest = BGProcessingTaskRequest(identifier: Self.cleanupTaskID)
        cleanupRequest.earliestBeginDate = Date(timeIntervalSinceNow: 86400)
        cleanupRequest.requiresNetworkConnectivity = false

        submit(cleanupRequest, name: "cleanup", category: AppLogger.data)
    }

    private func handleSyncTask(task: BGProcessingTask) {
        guard Self.cloudBackgroundServicesEnabled else {
            task.setTaskCompleted(success: true)
            AppLogger.debug("Background CloudKit sync skipped in DEBUG", category: AppLogger.cloudKit)
            return
        }

        let finisher = BackgroundTaskFinisher()
        let syncTask = Task {
            do {
                try await ModernCloudService.shared.sendChanges()
                guard finisher.finish(task, success: true) else { return }
                AppLogger.info("Background sync completed", category: AppLogger.cloudKit)
                scheduleSyncTask()
            } catch {
                guard finisher.finish(task, success: false) else { return }
                AppLogger.error("Background sync failed", category: AppLogger.cloudKit, error: error)
                scheduleSyncTask()
            }
        }

        task.expirationHandler = { [weak self] in
            syncTask.cancel()
            guard finisher.finish(task, success: false) else { return }
            self?.scheduleSyncTask()
        }
    }

    private func handleCleanupTask(task: BGProcessingTask) {
        let finisher = BackgroundTaskFinisher()
        let cleanupTask = Task {
            do {
                try await ModernCloudService.shared.cleanupGhostEntries()
                guard finisher.finish(task, success: true) else { return }
                AppLogger.info("Background cleanup completed", category: AppLogger.data)
                scheduleCleanupTask()
            } catch {
                guard finisher.finish(task, success: false) else { return }
                AppLogger.error("Background cleanup failed", category: AppLogger.data, error: error)
                scheduleCleanupTask()
            }
        }

        task.expirationHandler = { [weak self] in
            cleanupTask.cancel()
            guard finisher.finish(task, success: false) else { return }
            self?.scheduleCleanupTask()
        }
    }

    // MARK: - Setup

    private func setupPushNotifications() {
        guard Self.cloudBackgroundServicesEnabled else {
            AppLogger.debug("Remote CloudKit notifications disabled in DEBUG", category: AppLogger.cloudKit)
            return
        }

        // Enregistrement silencieux pour les push CloudKit (ne demande pas la permission utilisateur).
        // La permission pour les notifications locales est demandée dans NotificationSettingsView,
        // au moment où l'utilisateur active les rappels.
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
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
        guard Self.cloudBackgroundServicesEnabled else {
            completionHandler(.noData)
            return
        }

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
