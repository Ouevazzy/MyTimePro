import SwiftUI
import SwiftData
import CloudKit

@main
struct MyTimeProApp: App {
    let container: ModelContainer
    private let cloudKitContainerID = "iCloud.jordan-payez.MyTimePro"
    
    init() {
        do {
            let schema = Schema([WorkDay.self])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            
            container = try ModelContainer(
                for: WorkDay.self,
                configurations: modelConfiguration
            )
            
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .task {
                    setupCloudKitSync()
                }
        }
    }
    
    private func setupCloudKitSync() {
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        
        cloudContainer.accountStatus { status, error in
            if let error = error {
                print("CloudKit Account Error:", error.localizedDescription)
                return
            }
            
            if status == .available {
                let subscription = CKDatabaseSubscription(subscriptionID: "mytime-all-changes")
                let notificationInfo = CKSubscription.NotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                notificationInfo.shouldBadge = true
                subscription.notificationInfo = notificationInfo
                
                let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
                operation.qualityOfService = .userInitiated
                
                cloudContainer.privateCloudDatabase.add(operation)
                
                // Configuration d'une seule zone pour MyTimePro
                let customZone = CKRecordZone(zoneName: "MyTimeZone")
                let zoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone])
                
                zoneOperation.modifyRecordZonesResultBlock = { result in
                    switch result {
                    case .success:
                        print("CloudKit zone setup success")
                        self.setupZoneSubscription(container: cloudContainer)
                    case .failure(let error):
                        print("CloudKit zone setup error:", error.localizedDescription)
                    }
                }
                
                cloudContainer.privateCloudDatabase.add(zoneOperation)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            print("Remote change detected")
            Task { @MainActor in
                try? container.mainContext.save()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            setupCloudKitSync()
        }
    }
    
    private func setupZoneSubscription(container: CKContainer) {
        let zoneID = CKRecordZone.ID(zoneName: "MyTimeZone", ownerName: CKCurrentUserDefaultName)
        
        let subscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: "mytime-zone-changes"
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.qualityOfService = .userInitiated
        
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("CloudKit zone subscription setup success")
            case .failure(let error):
                print("CloudKit zone subscription error:", error.localizedDescription)
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
}