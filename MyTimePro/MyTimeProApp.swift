import SwiftUI
import SwiftData
import CloudKit

@main
struct MyTimeProApp: App {
    // MARK: - Properties
    let container: ModelContainer
    private let cloudKitContainerID = "iCloud.jordan-payez.MyTimePro"
    private let storeName = "MyTimePro.store"
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Initialization
    init() {
        do {
            container = try setupModelContainer()
            setupCloudSync()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    // MARK: - App Scene
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
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
    private func setupModelContainer() throws -> ModelContainer {
        // Configuration du schéma
        let schema = Schema([
            WorkDay.self
        ])
        
        // URL pour le stockage local
        let storeURL = URL.documentsDirectory.appending(path: storeName)
        
        // Configuration du modèle avec support CloudKit
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        
        // Création du conteneur
        return try ModelContainer(
            for: WorkDay.self,
            configurations: modelConfiguration
        )
    }
    
    private func setupCloudSync() {
        // Configuration du container CloudKit
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        
        // Configuration des zones
        let zones = [
            CKRecordZone(zoneName: "MyTimeProZone"),
            CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
        ]
        
        let zoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: zones)
        zoneOperation.qualityOfService = .utility
        
        // Configuration de la subscription
        let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let subscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        subscriptionOperation.qualityOfService = .utility
        
        // Exécution des opérations
        let database = cloudContainer.privateCloudDatabase
        database.add(zoneOperation)
        database.add(subscriptionOperation)
        
        // Configuration des notifications de changement
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Observer les changements distants
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task {
                try await handleRemoteChange()
            }
        }
        
        // Observer les changements de compte iCloud
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                try await requestSync()
            }
        }
        
        // Observer les notifications push CloudKit
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
        try await container.mainContext.save()
        try await requestSync()
    }
    
    private func requestSync() async throws {
        try await CloudService.shared.requestSync()
    }
    
    private func saveContext() async throws {
        try await container.mainContext.save()
    }
}
