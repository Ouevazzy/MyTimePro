import SwiftUI
import SwiftData
import CloudKit

@main
struct MyTimeProApp: App {
    // MARK: - Properties
    @StateObject private var modelContainer: ModelContainer
    private let cloudKitContainerID = "iCloud.jordan-payez.MyTimePro"
    private let storeName = "MyTimePro.store"
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Initialization
    init() {
        let container: ModelContainer
        do {
            container = try setupContainer()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
        _modelContainer = StateObject(wrappedValue: container)
    }
    
    // MARK: - App Scene
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .onAppear {
                    Task {
                        try? await requestSync()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    // MARK: - Private Setup Methods
    private func setupContainer() throws -> ModelContainer {
        let schema = Schema([WorkDay.self])
        let storeURL = URL.documentsDirectory.appending(path: storeName)
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        
        let container = try ModelContainer(
            for: WorkDay.self,
            configurations: modelConfiguration
        )
        
        setupCloudSync()
        return container
    }
    
    private func setupCloudSync() {
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        let zones = [
            CKRecordZone(zoneName: "MyTimeProZone"),
            CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
        ]
        
        let zoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: zones)
        zoneOperation.qualityOfService = .utility
        
        let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let subscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        subscriptionOperation.qualityOfService = .utility
        
        let database = cloudContainer.privateCloudDatabase
        database.add(zoneOperation)
        database.add(subscriptionOperation)
        
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                try await handleRemoteChange()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                try await requestSync()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CKDatabaseDidReceiveChanges"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                try await requestSync()
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                try await requestSync()
            }
        case .background:
            Task {
                try await saveContext()
            }
        default:
            break
        }
    }
    
    private func handleRemoteChange() async throws {
        try await modelContainer.mainContext.save()
        try await requestSync()
    }
    
    private func requestSync() async throws {
        await CloudService.shared.requestSync()
    }
    
    private func saveContext() async throws {
        try await modelContainer.mainContext.save()
    }
}