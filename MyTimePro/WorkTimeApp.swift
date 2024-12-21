import SwiftUI
import SwiftData
import CloudKit

@main
struct WorkTimeApp: App {
    // MARK: - Properties
    let container: ModelContainer
    private let cloudKitContainerID = "iCloud.jordan-payez.MyTimePro"
    @StateObject private var cloudService = CloudService.shared
    
    // MARK: - Initialization
    init() {
        print("📱 Initializing WorkTimeApp")
        do {
            let schema = Schema([WorkDay.self])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: URL.documentsDirectory.appending(path: "MyTimePro.store"),
                allowsSave: true,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            
            container = try ModelContainer(
                for: WorkDay.self,
                configurations: modelConfiguration
            )
            
            print("📱 ModelContainer initialized successfully")
            
            // Configure les notifications en arrière-plan pour CloudKit
            configureBackgroundTasks()
            
        } catch {
            print("❌ Failed to initialize ModelContainer: \(error.localizedDescription)")
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .environmentObject(cloudService)
                .task {
                    await setupCloudKitSync()
                }
                .onAppear {
                    registerForPushNotifications()
                }
        }
    }
    
    // MARK: - Private Methods
    private func setupCloudKitSync() async {
        print("📱 Setting up CloudKit sync")
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        
        do {
            let accountStatus = try await cloudContainer.accountStatus()
            if accountStatus == .available {
                print("📱 iCloud account is available")
                
                // Création de la zone personnalisée
                let customZone = CKRecordZone(zoneName: "WorkTimeZone")
                let modifyOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone])
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOperation.modifyRecordZonesResultBlock = { result in
                        switch result {
                        case .success:
                            print("📱 CloudKit zone setup success")
                            continuation.resume()
                        case .failure(let error):
                            print("❌ CloudKit zone setup error: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    cloudContainer.privateCloudDatabase.add(modifyOperation)
                }
                
                // Configuration des subscriptions
                await setupSubscriptions(container: cloudContainer)
                
            } else {
                print("⚠️ iCloud account is not available: \(accountStatus)")
            }
        } catch {
            print("❌ Error setting up CloudKit sync: \(error.localizedDescription)")
        }
    }
    
    private func setupSubscriptions(container: CKContainer) async {
        print("📱 Setting up CloudKit subscriptions")
        do {
            // Subscription pour tous les changements
            let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            try await container.privateCloudDatabase.save(subscription)
            print("📱 Database subscription saved successfully")
            
            // Subscription pour les changements spécifiques aux WorkDays
            let predicate = NSPredicate(value: true)
            let querySubscription = CKQuerySubscription(
                recordType: "WorkDay",
                predicate: predicate,
                subscriptionID: "mytimepro-workday-changes",
                options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
            )
            querySubscription.notificationInfo = notificationInfo
            
            try await container.privateCloudDatabase.save(querySubscription)
            print("📱 WorkDay subscription saved successfully")
            
        } catch {
            print("❌ Error setting up subscriptions: \(error.localizedDescription)")
        }
    }
    
    private func configureBackgroundTasks() {
        print("📱 Configuring background tasks")
        if UIApplication.shared.backgroundRefreshStatus == .available {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }
    }
    
    private func registerForPushNotifications() {
        print("📱 Registering for push notifications")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("📱 Push notification authorization granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("❌ Push notification authorization error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UIApplicationDelegate
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