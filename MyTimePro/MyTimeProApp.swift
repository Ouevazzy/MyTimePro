
<<<<<<< Updated upstream
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
                setupSubscriptions(for: cloudContainer)
                print("CloudKit is available. Sync setup complete.")
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
    
    private func setupSubscriptions(for cloudContainer: CKContainer) {
        let privateDatabase = cloudContainer.privateCloudDatabase
        let subscription = CKDatabaseSubscription(subscriptionID: "mytime-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("CloudKit subscription setup success")
            case .failure(let error):
                print("CloudKit subscription error:", error.localizedDescription)
            }
        }
        
        privateDatabase.add(operation)
    }
}
=======
>>>>>>> Stashed changes
