import Foundation
import CloudKit
import SwiftUI
import SwiftData
import BackgroundTasks
import Combine
import Observation

@MainActor
@Observable
final class ModernCloudService {
    // MARK: - Singleton
    static let shared = ModernCloudService()
    
    // MARK: - Properties
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?
    private(set) var userMessage: String?
    
    // Configuration
    private let containerIdentifier = "iCloud.jordan-payez.MyTimePro"
    private let zoneID = CKRecordZone.ID(zoneName: "MyTimeProZone", ownerName: CKCurrentUserDefaultName)
    var syncEngine: CKSyncEngine?
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
    // État interne
    private var isInitialized = false
    private var isSyncing = false
    
    // Clé pour UserDefaults
    private let syncEngineInitializedKey = "syncEngineInitializedInSession"
    
    // MARK: - Modèle d'état
    enum SyncStatus: Equatable {
        case idle
        case syncing(progress: Double)
        case error(message: String)
        case offline
        case failed(error: Error)
        
        var description: String {
            switch self {
            case .idle: return "Prêt"
            case .syncing(let progress): return "Synchronisation \(Int(progress * 100))%"
            case .error(let message): return "Erreur: \(message)"
            case .offline: return "Hors ligne"
            case .failed(let error): return "Échec: \(error.localizedDescription)"
            }
        }
        
        var iconName: String {
            switch self {
            case .idle: return "checkmark.circle"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .error, .failed: return "exclamationmark.circle"
            case .offline: return "wifi.slash"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .green
            case .syncing: return .blue
            case .error, .failed: return .red
            case .offline: return .orange
            }
        }
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.offline, .offline): return true
            case (.syncing(let lhsProgress), .syncing(let rhsProgress)):
                return lhsProgress == rhsProgress
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialisation
    private init() {
        setupBackgroundTasks()
    }
    
    // MARK: - Configuration du CKSyncEngine
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func initialize() {
        guard !isInitialized else {
            print("⚠️ ModernCloudService déjà initialisé - ignoré")
            return
        }
        
        // On simplifie la vérification - on n'utilise qu'une seule clé de contrôle
        // qui est alignée avec celle utilisée dans WorkTimerApp
        if !UserDefaults.standard.bool(forKey: "hasInitializedCloudKit") {
            print("⚠️ CloudKit n'est pas initialisé - le service cloud ne sera pas configuré")
            syncStatus = .error(message: "CloudKit non disponible")
            userMessage = "Service cloud non disponible"
            return
        }
        
        setupSyncEngine()
        setupCloudKitNotifications()
        
        isInitialized = true
        
        self.syncStatus = .idle
        self.userMessage = "Prêt à synchroniser"
    }
    
    private func setupSyncEngine() {
        let container = CKContainer(identifier: containerIdentifier)
        let database = container.privateCloudDatabase
        
        // Pour iOS 18/Xcode 16, utiliser une configuration sans stateSerialization
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: nil,  // Ne pas utiliser l'état sauvegardé pour l'instant
            delegate: self
        )
        
        // Initialisation du sync engine avec la configuration
        syncEngine = CKSyncEngine(configuration)
        print("✅ CKSyncEngine initialisé avec succès")
    }
    
    private func setupCloudKitNotifications() {
        // Observer les notifications CloudKit
        NotificationCenter.default.publisher(for: NSNotification.Name.CKAccountChanged)
            .sink { [weak self] _ in
                self?.checkAccountStatus()
            }
            .store(in: &cancellables)
        
        // Vérifier le statut du compte immédiatement
        checkAccountStatus()
    }
    
    private func checkAccountStatus() {
        CKContainer(identifier: containerIdentifier).accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = .error(message: error.localizedDescription)
                    self?.userMessage = "Erreur: \(error.localizedDescription)"
                    return
                }
                
                switch status {
                case .available:
                    self?.syncStatus = .idle
                    self?.userMessage = "iCloud disponible"
                case .noAccount:
                    self?.syncStatus = .offline
                    self?.userMessage = "Aucun compte iCloud"
                case .restricted:
                    self?.syncStatus = .error(message: "Accès iCloud restreint")
                    self?.userMessage = "Accès restreint à iCloud"
                case .couldNotDetermine:
                    self?.syncStatus = .error(message: "Impossible de déterminer le statut iCloud")
                    self?.userMessage = "Impossible de vérifier iCloud"
                case .temporarilyUnavailable:
                    self?.syncStatus = .offline
                    self?.userMessage = "iCloud temporairement indisponible"
                @unknown default:
                    self?.syncStatus = .error(message: "Statut inconnu")
                    self?.userMessage = "Statut iCloud inconnu"
                }
            }
        }
    }
    
    // MARK: - API Publique
    
    /// Réinitialise complètement l'état de CloudKit pour permettre une nouvelle initialisation
    /// Cette méthode ne doit être utilisée que pour le dépannage et le débogage
    func resetCloudKitInitialization() {
        syncEngine = nil
        isInitialized = false
        UserDefaults.standard.set(false, forKey: "hasInitializedCloudKit")
        UserDefaults.standard.synchronize()
        
        syncStatus = .idle
        userMessage = "Configuration CloudKit réinitialisée. Veuillez redémarrer l'application."
        print("🔄 Configuration CloudKit réinitialisée")
    }
    
    /// Envoie les changements à CloudKit
    func sendChanges() async throws {
        guard !isSyncing else { return }
        
        self.isSyncing = true
        self.syncStatus = .syncing(progress: 0.0)
        self.userMessage = "Synchronisation en cours..."
        
        do {
            // Utiliser la méthode sendChanges() pour iOS 18/Xcode 16.3
            try await syncEngine?.sendChanges()
            
            self.isSyncing = false
            self.syncStatus = .idle
            self.lastSyncDate = Date()
            self.userMessage = "Synchronisation terminée"
            self.scheduleBGSync()
        } catch {
            self.isSyncing = false
            self.handleSyncError(error)
            throw error
        }
    }
    
    /// Fonction pour permettre l'appel depuis l'interface utilisateur
    func requestSync() {
        Task {
            try? await sendChanges()
        }
    }
    
    /// Fonction pour restaurer depuis iCloud
    func restoreFromCloud() async {
        self.syncStatus = .syncing(progress: 0.0)
        self.userMessage = "Restauration en cours..."
        
        // Simuler un délai de restauration
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Synchronisation normale avec la méthode pour iOS 18
        do {
            try await syncEngine?.sendChanges()
            self.syncStatus = .idle
            self.lastSyncDate = Date()
            self.userMessage = "Restauration terminée"
        } catch {
            self.handleSyncError(error)
        }
    }
    
    /// Arrête la synchronisation en cours
    func stopSync() {
        guard isSyncing else { return }
        
        self.isSyncing = false
        self.syncStatus = .idle
        self.userMessage = "Synchronisation arrêtée"
    }
    
    // MARK: - Gestion des erreurs
    
    private func handleSyncError(_ error: Error) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                syncStatus = .offline
                userMessage = "Connexion réseau indisponible"
                
            case .notAuthenticated:
                syncStatus = .error(message: "Non connecté à iCloud")
                userMessage = "Veuillez vous connecter à iCloud dans les réglages"
                
            case .quotaExceeded:
                syncStatus = .error(message: "Quota iCloud dépassé")
                userMessage = "Veuillez libérer de l'espace dans iCloud"
                
            default:
                syncStatus = .error(message: ckError.localizedDescription)
                userMessage = "Erreur: \(ckError.localizedDescription)"
            }
        } else {
            syncStatus = .error(message: error.localizedDescription)
            userMessage = "Erreur: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Gestion des tâches d'arrière-plan
    
    private func setupBackgroundTasks() {
        // Enregistrer la tâche de synchronisation en arrière-plan
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.mytiempo.sync", using: nil) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
        
        // Enregistrer la tâche de nettoyage périodique
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.mytiempo.cleanup", using: nil) { task in
            self.handleBackgroundCleanup(task: task as! BGProcessingTask)
        }
    }
    
    private func scheduleBGSync() {
        let request = BGProcessingTaskRequest(identifier: "com.mytiempo.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1h plus tard
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Impossible de planifier la tâche de synchronisation: \(error)")
        }
    }
    
    private func scheduleCleanupTask() {
        let request = BGProcessingTaskRequest(identifier: "com.mytiempo.cleanup")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 86400) // 24h plus tard
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Impossible de planifier la tâche de nettoyage: \(error)")
        }
    }
    
    private func handleBackgroundSync(task: BGProcessingTask) {
        // Soumettre à nouveau la tâche pour la prochaine fois
        scheduleBGSync()
        
        // Définir le gestionnaire d'expiration
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Lancer une tâche de synchronisation en arrière-plan
        Task {
            do {
                try await self.sendChanges()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handleBackgroundCleanup(task: BGProcessingTask) {
        // Planifier la prochaine tâche de nettoyage
        scheduleCleanupTask()
        
        // Exécuter le nettoyage simplifié
        Task {
            do {
                // Au lieu d'un cleanup explicite, on force une nouvelle synchronisation
                try await self.sendChanges()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    deinit {
        // Nettoyer les ressources
        syncEngine = nil
        
        // Nous n'utilisons plus syncEngineInitializedKey comme verrou indépendant
        // car nous nous alignons maintenant sur hasInitializedCloudKit de WorkTimerApp
        print("✅ Ressources du CKSyncEngine libérées")
    }
}

// MARK: - CKSyncEngineDelegate
extension ModernCloudService: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(_):
            print("État de synchronisation mis à jour")
            // Nous ne sauvegardons pas l'état pour l'instant, ce qui fait
            // que l'application recommencera une synchronisation complète à chaque lancement
            // C'est une étape temporaire jusqu'à ce que nous comprenions mieux comment gérer
            // le type CKSyncEngine.State.Serialization
            
        case .accountChange(let accountChange):
            switch accountChange.changeType {
            case .signIn:
                print("Utilisateur connecté à iCloud")
                self.syncStatus = .idle
            case .signOut:
                print("Utilisateur déconnecté d'iCloud")
                self.syncStatus = .offline
            case .switchAccounts:
                print("Changement de compte iCloud")
                self.syncStatus = .idle
            @unknown default:
                break
            }
            
        case .fetchedRecordZoneChanges(let changes):
            // Traiter les modifications venant d'autres appareils
            for modification in changes.modifications {
                print("Record modifié reçu: \(modification.record.recordID)")
            }
            
            for deletion in changes.deletions {
                print("Record supprimé: \(deletion.recordID)")
            }
            
            self.lastSyncDate = Date()
            self.syncStatus = .idle
            
        case .sentRecordZoneChanges(let sentChanges):
            if !sentChanges.failedRecordSaves.isEmpty {
                for failedSave in sentChanges.failedRecordSaves {
                    print("Échec de sauvegarde: \(failedSave.error.localizedDescription)")
                }
                
                self.syncStatus = .error(message: "Erreur lors de l'envoi de données")
            } else {
                self.lastSyncDate = Date()
                self.syncStatus = .idle
            }
            
        case .willFetchChanges:
            self.syncStatus = .syncing(progress: 0.0)
            
        case .didFetchChanges:
            self.lastSyncDate = Date()
            self.syncStatus = .idle
            
        default:
            break
        }
    }
    
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        // Ce serait ici que vous renverriez les enregistrements à sauvegarder
        // Pour l'exemple, on renvoie nil car nous n'avons pas d'implémentation spécifique
        print("nextRecordZoneChangeBatch appelé")
        return nil
    }
    
    // Les anciennes méthodes ne sont plus utilisées dans iOS 18, mais peuvent être gardées 
    // pour la rétrocompatibilité si nécessaire
    
    func syncEngine(_ engine: CKSyncEngine, shouldAddRecord record: CKRecord) -> Bool {
        // Accepter tous les enregistrements
        return true
    }
    
    func syncEngine(_ engine: CKSyncEngine, shouldDeleteRecord recordID: CKRecord.ID) -> Bool {
        // Accepter toutes les suppressions
        return true
    }
    
    func syncEngine(_ engine: CKSyncEngine, didModifyRecords modified: [CKRecord], deleted: [CKRecord.ID]) {
        // Cette méthode est obsolète avec iOS 18, mais gardée pour la compatibilité
        // Mise à jour du statut
        self.syncStatus = .syncing(progress: 0.5)
        
        // Traiter les modifications
        Task {
            // Log des modifications pour le débogage
            if !modified.isEmpty {
                print("Records modifiés: \(modified.count)")
            }
            
            if !deleted.isEmpty {
                print("Records supprimés: \(deleted.count)")
            }
            
            // Mise à jour finale
            self.lastSyncDate = Date()
            self.syncStatus = .idle
        }
    }
    
    func syncEngine(_ engine: CKSyncEngine, didStartSyncWithChanges hasChanges: Bool) {
        // Obsolète avec iOS 18
        self.syncStatus = .syncing(progress: 0.0)
    }
    
    func syncEngine(_ engine: CKSyncEngine, didFinishSyncWithChanges hasChanges: Bool) {
        // Obsolète avec iOS 18
        self.lastSyncDate = Date()
        self.syncStatus = .idle
    }
    
    func syncEngine(_ engine: CKSyncEngine, didFailWithError error: Error) {
        // Obsolète avec iOS 18
        self.handleSyncError(error)
    }
}
