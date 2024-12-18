import SwiftUI
import SwiftData
import CloudKit

@main
struct MyTimeProApp: App {
    // MARK: - Properties
    @State private var modelContainer: ModelContainer?
    private let cloudKitContainerID = "iCloud.jordan-payez.MyTimePro"
    private let storeName = "MyTimePro.store"
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - App Scene
    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
                    .preferredColorScheme(.dark)
                    .task {
                        await setupCloudSync()
                        await requestSync()
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        handleScenePhaseChange(newPhase)
                    }
            } else {
                ProgressView("Loading...")
                    .task {
                        do {
                            modelContainer = try await setupContainer()
                        } catch {
                            print("Failed to initialize ModelContainer: \(error.localizedDescription)")
                        }
                    }
            }
        }
    }
    
    // MARK: - Private Setup Methods
    private func setupContainer() async throws -> ModelContainer {
        let schema = Schema([WorkDay.self])
        let storeURL = URL.documentsDirectory.appending(path: storeName)
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        
        return try ModelContainer(
            for: schema,
            configurations: modelConfiguration
        )
    }
    
    private func setupCloudSync() async {
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        let database = cloudContainer.privateCloudDatabase
        
        // Create zones
        let zones = [
            CKRecordZone(zoneName: "MyTimeProZone"),
            CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
        ]
        
        do {
            try await database.save(zones[0])
            try await database.save(zones[1])
        } catch {
            print("Failed to save zones: \(error.localizedDescription)")
        }
        
        // Setup subscription
        let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        do {
            try await database.save(subscription)
        } catch {
            print("Failed to save subscription: \(error.localizedDescription)")
        }
        
        setupNotificationObservers()
    }
    
    @MainActor
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await handleRemoteChange()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await requestSync()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CKDatabaseDidReceiveChanges"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await requestSync()
            }
        }
    }
    
    // MARK: - Event Handlers
    @MainActor
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                await requestSync()
            }
        case .background:
            Task {
                await saveContext()
            }
        default:
            break
        }
    }
    
    @MainActor
    private func handleRemoteChange() async {
        guard let container = modelContainer else { return }
        do {
            try await container.mainContext.save()
            await requestSync()
        } catch {
            print("Error handling remote change: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func requestSync() async {
        await CloudService.shared.requestSync()
    }
    
    @MainActor
    private func saveContext() async {
        guard let container = modelContainer else { return }
        do {
            try await container.mainContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}