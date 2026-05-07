import SwiftUI
import SwiftData
import CloudKit

@main
struct MyTimeProApp: App {
    let container: ModelContainer
    private let cloudService = CloudService.shared
    
    init() {
        do {
            // Configuration du schéma SwiftData
            let schema = Schema([
                WorkDay.self // Ajoutez ici d'autres modèles si nécessaires
            ])
            
            // Configuration du conteneur avec support CloudKit
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: URL.documentsDirectory.appending(path: "MyTimePro.store"),
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.jordan-payez.MyTimePro") // Remplacez par votre identifiant iCloud
            )
            
            // Initialisation du conteneur SwiftData
            container = try ModelContainer(
                for: WorkDay.self,
                configurations: modelConfiguration
            )
            
            // Liaison du service CloudKit au contexte SwiftData
            cloudService.setModelContext(container.mainContext)
            
        } catch {
            fatalError("Échec de l'initialisation du ModelContainer : \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .preferredColorScheme(.dark) // Thème sombre par défaut
                .onAppear {
                    setupCloudKitSync()
                }
                .onChange(of: container.mainContext.hasChanges) { _, hasChanges in
                    if hasChanges {
                        saveContext()
                    }
                }
        }
    }
    
    private func setupCloudKitSync() {
        // Vérification initiale du statut iCloud
        cloudService.checkiCloudStatus()
        
        // Ajout d'observateurs pour les notifications de changements de données
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DataDidChange"),
            object: nil,
            queue: .main
        ) { notification in
            if notification.userInfo?["record"] != nil {
                Task { @MainActor in
                    saveContext()
                }
            }
        }
    }
    
    private func saveContext() {
        Task { @MainActor in
            do {
                try container.mainContext.save()
                print("Contexte principal sauvegardé avec succès.")
            } catch {
                print("Erreur lors de la sauvegarde du contexte principal : \(error.localizedDescription)")
            }
        }
    }
}
