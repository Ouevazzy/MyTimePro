import SwiftUI
import SwiftData
import CloudKit

@main
struct WorkTimeApp: App {
    // MARK: - Properties
    private let modelContainer: ModelContainer
    private let cloudKitContainerID = "iCloud.jordan-payez.MyTimePro"
    private let cloudKitZoneName = "MyTimeProZone"
    
    // MARK: - Initialization
    init() {
        print("📱 Initializing WorkTimeApp")
        do {
            let schema = Schema([WorkDay.self])
            
            // Configuration SwiftData avec CloudKit
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: URL.documentsDirectory.appending(path: "MyTimePro.store"),
                cloudKitContainerIdentifier: cloudKitContainerID,
                cloudKitSynchronizationZoneName: cloudKitZoneName
            )
            
            modelContainer = try ModelContainer(
                for: WorkDay.self,
                configurations: modelConfiguration
            )
            
            print("📱 ModelContainer initialized successfully")
            setupCloudKit()
            
        } catch {
            print("❌ Failed to initialize ModelContainer: \(error.localizedDescription)")
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .onAppear {
                    registerForPushNotifications()
                }
        }
    }
    
    // MARK: - Private Methods
    private func setupCloudKit() {
        print("📱 Setting up CloudKit")
        
        // Configurer le container CloudKit
        let container = CKContainer(identifier: cloudKitContainerID)
        
        // Vérifier l'état du compte iCloud
        container.accountStatus { status, error in
            if let error = error {
                print("❌ CloudKit Account Error: \(error.localizedDescription)")
                return
            }
            
            if status == .available {
                print("📱 iCloud account is available")
                
                // Configuration de la zone personnalisée
                let customZone = CKRecordZone(zoneName: cloudKitZoneName)
                let operation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone])
                
                operation.modifyRecordZonesResultBlock = { result in
                    switch result {
                    case .success:
                        print("📱 CloudKit zone setup success")
                        setupSubscription(container: container)
                    case .failure(let error):
                        print("❌ CloudKit zone setup error: \(error.localizedDescription)")
                    }
                }
                
                container.privateCloudDatabase.add(operation)
            } else {
                print("❌ iCloud account is not available: \(status)")
            }
        }
    }
    
    private func setupSubscription(container: CKContainer) {
        print("📱 Setting up CloudKit subscriptions")
        
        // Subscription pour tous les changements de la base de données
        let subscriptionID = "mytimepro-all-changes"
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.qualityOfService = .utility
        
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("📱 CloudKit subscription setup success")
            case .failure(let error):
                print("❌ CloudKit subscription error: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
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
    
    private func cleanupDeletedRecords(context: ModelContext) {
        print("📱 Cleaning up deleted records")
        
        let descriptor = FetchDescriptor<WorkDay>(predicate: #Predicate<WorkDay> { workDay in
            workDay.isDeleted
        })
        
        do {
            let deletedRecords = try context.fetch(descriptor)
            for record in deletedRecords {
                context.delete(record)
            }
            try context.save()
            print("📱 Successfully cleaned up \(deletedRecords.count) deleted records")
        } catch {
            print("❌ Error cleaning up deleted records: \(error)")
        }
    }
}
