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
                        do {
                            try await setupCloudSync()
                            try await requestSync()
                        } catch {
                            print("Failed to setup cloud sync: \(error)")
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        Task {
                            do {
                                try await handleScenePhaseChange(newPhase)
                            } catch {
                                print("Error handling scene phase change: \(error)")
                            }
                        }
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
    
    private func setupCloudSync() async throws {
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        let database = cloudContainer.privateCloudDatabase
        
        // Create zones
        let zones = [
            CKRecordZone(zoneName: "MyTimeProZone"),
            CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
        ]
        
        for zone in zones {
            try await database.save(zone)
        }
        
        // Setup subscription
        let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await database.save(subscription)
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                do {
                    try await handleRemoteChange()
                } catch {
                    print("Failed to handle remote change: \(error)")
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                do {
                    try await requestSync()
                } catch {
                    print("Failed to sync after account change: \(error)")
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CKDatabaseDidReceiveChanges"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                do {
                    try await requestSync()
                } catch {
                    print("Failed to sync after receiving changes: \(error)")
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleScenePhaseChange(_ newPhase: ScenePhase) async throws {
        switch newPhase {
        case .active:
            try await requestSync()
            try await CloudService.shared.requestSync()
        case .background:
            try await saveContext()
            try await container?.mainContext.save()
        default:
            break
        }
    }
    
    @MainActor
    private func handleRemoteChange() async throws {
        guard let container = modelContainer else { return }
        try await container.mainContext.save()
        try await CloudService.shared.requestSync()
    }
    
    @MainActor
    private func requestSync() async throws {
        try await CloudService.shared.requestSync()
    }
    
    @MainActor
    private func saveContext() async throws {
        guard let container = modelContainer else { return }
        try await container.mainContext.save()
    }
}