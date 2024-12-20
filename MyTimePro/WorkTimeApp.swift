import SwiftUI
import SwiftData
import CloudKit

@main
struct WorkTimeApp: App {
    let container: ModelContainer
    private let cloudKitContainerID = "iCloud.jordan-payez.WorkTimer"
    
    init() {
        do {
            // Configuration avec historique de persistance
            let schema = Schema([WorkDay.self])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: URL.documentsDirectory.appending(path: "WorkTime.store"),
                allowsSave: true,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            
            // Création du container
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
        // Configuration du container CloudKit
        let cloudContainer = CKContainer(identifier: cloudKitContainerID)
        
        // Vérification de l'état iCloud
        cloudContainer.accountStatus { status, error in
            if let error = error {
                print("CloudKit Account Error:", error.localizedDescription)
                return
            }
            
            if status == .available {
                // Configuration de la synchronisation de base de données
                let subscription = CKDatabaseSubscription(subscriptionID: "worktime-all-changes")
                let notificationInfo = CKSubscription.NotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                subscription.notificationInfo = notificationInfo
                
                // Configuration de la modification
                let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
                operation.qualityOfService = .userInitiated
                
                // Envoi de l'opération
                cloudContainer.privateCloudDatabase.add(operation)
                
                // Configuration de la zone
                let customZone = CKRecordZone(zoneName: "WorkTimeZone")
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
        
        // Observation des notifications pour les changements
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            print("Remote change detected")
            Task {
                await saveContext()
            }
        }

    @MainActor
    private func saveContext() {
        do {
            try container.mainContext.save()
        } catch {
            print("Erreur lors de la sauvegarde du contexte : \(error.localizedDescription)")
        }
    }
        } catch {
            print("Erreur lors de la sauvegarde du contexte : \(error.localizedDescription)")
        }
    }
        }
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
        _ = CKRecordZone.ID(zoneName: "WorkTimeZone", ownerName: CKCurrentUserDefaultName)
        
        // Création de la subscription pour la zone spécifique
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "WorkDay",
            predicate: predicate,
            subscriptionID: "worktime-zone-changes",
            options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
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
