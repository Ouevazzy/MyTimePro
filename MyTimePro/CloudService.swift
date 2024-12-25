import Foundation
import CloudKit
import SwiftUI
import SwiftData

@Observable
class CloudService: ObservableObject {
    // MARK: - Singleton
    static let shared = CloudService()
    
    // MARK: - Published Properties
    private(set) var iCloudStatus: CloudStatus = .unknown {
        didSet {
            if iCloudStatus == .available && !isSetup {
                setupSync()
            } else if iCloudStatus == .available {
                performSyncIfNeeded()
            }
        }
    }
    private(set) var lastSyncDate: Date?
    private(set) var syncProgress: Double = 0
    private(set) var lastError: Error?
    
    // Indicateur de restauration + progression
    private(set) var isRestoring = false
    private(set) var restorationProgress: Double = 0
    
    // Message à afficher à l’utilisateur (status, avertissements, etc.)
    var userMessage: String?
    
    // MARK: - Private Properties
    private let container: CKContainer
    private let database: CKDatabase
    
    private let zoneName = "MyTimeProZone"
    private let iCloudIdentifier = "iCloud.jordan-payez.MyTimePro"
    
    private var isSubscribed = false
    private var isSetup = false
    private var lastCheckDate: Date = .distantPast
    private var modelContext: ModelContext?
    
    // Token CloudKit pour suivre l’état de la dernière synchro
    private var lastChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.data(forKey: "lastChangeToken") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        set {
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "lastChangeToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastChangeToken")
            }
        }
    }
    
    // MARK: - CloudStatus
    enum CloudStatus: Equatable {
        case unknown
        case available
        case unavailable
        case restricted
        case syncing(progress: Double)
        case error(Error)
        
        static func == (lhs: CloudStatus, rhs: CloudStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown),
                 (.available, .available),
                 (.unavailable, .unavailable),
                 (.restricted, .restricted):
                return true
            case let (.syncing(p1), .syncing(p2)):
                return p1 == p2
            case let (.error(e1), .error(e2)):
                let nse1 = e1 as NSError
                let nse2 = e2 as NSError
                return nse1.domain == nse2.domain && nse1.code == nse2.code
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .unknown: return "Vérification..."
            case .available: return "Synchronisé"
            case .unavailable: return "iCloud non disponible"
            case .restricted: return "Accès restreint"
            case .syncing(let progress): return "Synchronisation \(Int(progress * 100))%"
            case .error(let error): return "Erreur: \(error.localizedDescription)"
            }
        }
        
        var iconName: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .available: return "checkmark.circle"
            case .unavailable: return "xmark.circle"
            case .restricted: return "exclamationmark.triangle"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .available: return .green
            case .unavailable: return .red
            case .restricted: return .yellow
            case .syncing: return .blue
            case .error: return .orange
            }
        }
        
        var isAvailable: Bool {
            switch self {
            case .available, .syncing:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        container = CKContainer(identifier: iCloudIdentifier)
        database = container.privateCloudDatabase
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Définit le ModelContext (SwiftData) et déclenche la vérification iCloud.
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        checkiCloudStatus()
    }
    
    /// Vérifie l'état du compte iCloud (disponible, restreint, etc.)
    func checkiCloudStatus() {
        guard shouldPerformStatusCheck() else { return }
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error {
                    self?.handleCloudKitError(error)
                    return
                }
                
                switch status {
                case .available:
                    self?.updateStatus(.available)
                case .restricted:
                    self?.updateStatus(.restricted)
                case .noAccount:
                    self?.updateStatus(.unavailable)
                case .couldNotDetermine, .temporarilyUnavailable:
                    self?.updateStatus(.unknown)
                @unknown default:
                    self?.updateStatus(.unknown)
                }
            }
        }
    }
    
    /// Demande une synchronisation manuelle (si iCloud est disponible).
    func requestSync() {
        guard iCloudStatus == .available else { return }
        performSync()
    }
    
    /// Restaure toutes les données WorkDay depuis iCloud dans un flux asynchrone unique,
    /// pour éviter la capture concurrente d'un tableau "allRecords".
    func restoreFromCloud() async {
        guard iCloudStatus.isAvailable else { return }
        
        // Prépare l'UI
        await MainActor.run {
            isRestoring = true
            restorationProgress = 0
            userMessage = "Début de la restauration..."
        }
        
        do {
            // 1) Créer / vérifier la zone iCloud
            let zone = CKRecordZone(zoneName: zoneName)
            let createZoneOp = CKModifyRecordZonesOperation(recordZonesToSave: [zone])
            // Pas de try/await, car database.add(...) n'est ni async ni throws
            database.add(createZoneOp)
            
            // 2) Préparer la requête
            let query = CKQuery(recordType: "WorkDay", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            
            // 3) Récupérer tous les enregistrements
            //    On appelle une fonction "throws", donc on met "try await".
            let allRecords = try await fetchAllRecords(query: query)
            
            // 4) Appliquer les modifications sur le MainActor
            await MainActor.run {
                userMessage = "Application des modifications..."
                
                guard let context = modelContext else {
                    userMessage = "Pas de ModelContext disponible."
                    isRestoring = false
                    return
                }
                
                for (index, record) in allRecords.enumerated() {
                    handleRecordChange(record, in: context)
                    restorationProgress = Double(index + 1) / Double(allRecords.count)
                }
                
                // Si "save()" est throwing, mettre try + do/catch ou try?
                // Sinon, laissez tel quel.
                do {
                    try context.save()
                } catch {
                    print("Erreur lors de la sauvegarde: \(error)")
                }
                
                isRestoring = false
                restorationProgress = 1.0
                lastSyncDate = Date()
                userMessage = "Restauration terminée (\(allRecords.count) enregistrements)"
            }
            
        } catch {
            // Appel de la méthode @MainActor dans un bloc asynchrone
            Task { @MainActor [weak self] in
                self?.handleCloudKitError(error)
                self?.isRestoring = false
                self?.userMessage = "Erreur lors de la restauration: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Fonction asynchrone qui récupère TOUTES les données d'une requête CKQuery
    /// (boucle sur le cursor pour tout ramener).
    private func fetchAllRecords(query: CKQuery) async throws -> [CKRecord] {
        var finalRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            // fetchRecords(...) est "throws", donc "try await".
            let (batch, nextCursor) = try await fetchRecords(query: query, cursor: cursor)
            finalRecords.append(contentsOf: batch)
            cursor = nextCursor
            
            // Éviter de capturer tout "finalRecords" dans la closure concurrente :
            let currentCount = finalRecords.count
            
            // (Optionnel) feedback partiel :
            await MainActor.run {
                self.userMessage = "Récupération (\(currentCount) enregistrements)..."
            }
            
        } while cursor != nil
        
        return finalRecords
    }
    
    /// Récupère un batch d'enregistrements CloudKit selon une `query` + un `cursor`.
    /// - Returns: Un tuple ([CKRecord], CKQueryOperation.Cursor?) pour la pagination
    /// - Throws:  En cas d'échec de l'opération
    private func fetchRecords(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        var records: [CKRecord] = []
        
        let operation: CKQueryOperation
        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            operation = CKQueryOperation(query: query)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    // On peut logguer l'erreur mais on ne "throw" pas directement
                    print("Erreur recordMatchedBlock: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let newCursor):
                    continuation.resume(returning: (records, newCursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Pas de try/await ici, "database.add" n'étant pas async ni throws
            database.add(operation)
        }
    }
    
    /// Upload un `WorkDay` spécifique vers iCloud.
    func uploadWorkDay(_ workDay: WorkDay) {
        guard iCloudStatus == .available else { return }
        
        let record = createCloudKitRecord(from: workDay)
        let operation = CKModifyRecordsOperation(recordsToSave: [record])
        
        operation.modifyRecordsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    workDay.cloudKitRecordID = record.recordID.recordName
                    // Si save() est throwing :
                    do {
                        try self?.modelContext?.save()
                    } catch {
                        print("Erreur lors de la sauvegarde (uploadWorkDay): \(error)")
                    }
                    self?.lastSyncDate = Date()
                    
                case .failure(let error):
                    // handleCloudKitError est @MainActor, on peut l'appeler sur le main thread
                    Task { @MainActor [weak self] in
                        self?.handleCloudKitError(error)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /// Installe les notifications CloudKit pour suivre les changements de compte.
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudAccountChanged),
            name: .CKAccountChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteNotification),
            name: NSNotification.Name("CKDatabaseDidReceiveChanges"),
            object: nil
        )
    }
    
    /// Crée la zone iCloud si besoin et souscrit aux notifications (change subscription).
    private func setupSync() {
        let zone = CKRecordZone(zoneName: zoneName)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone])
        
        operation.modifyRecordZonesResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isSetup = true
                    self?.setupSubscription()
                case .failure(let error):
                    Task { @MainActor [weak self] in
                        self?.handleCloudKitError(error)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /// Met en place la subscription CloudKit pour recevoir des notifications push en cas de changement.
    private func setupSubscription() {
        guard !isSubscribed else { return }
        
        let subscription = CKDatabaseSubscription(subscriptionID: "all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.modifySubscriptionsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isSubscribed = true
                    self?.lastSyncDate = Date()
                case .failure(let error):
                    Task { @MainActor [weak self] in
                        self?.handleCloudKitError(error)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /// Lance le processus de synchronisation (fetch des changements depuis la base).
    private func performSync() {
        Task { @MainActor in
            updateStatus(.syncing(progress: 0))
            
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: lastChangeToken)
            
            operation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
                Task {
                    await self?.fetchZoneChanges(zoneID)
                }
            }
            
            operation.changeTokenUpdatedBlock = { [weak self] token in
                self?.lastChangeToken = token
            }
            
            operation.fetchDatabaseChangesResultBlock = { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.lastSyncDate = Date()
                        self?.updateStatus(.available)
                    case .failure(let error):
                        self?.handleCloudKitError(error)
                    }
                }
            }
            
            database.add(operation)
        }
    }
    
    /// Récupère les changements pour une zone (CKFetchRecordZoneChangesOperation).
    private func fetchZoneChanges(_ zoneID: CKRecordZone.ID) async {
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )
        
        operation.recordWasChangedBlock = { [weak self] recordID, result in
            Task { @MainActor in
                switch result {
                case .success(let record):
                    if let context = self?.modelContext {
                        self?.handleRecordChange(record, in: context)
                    }
                case .failure(let error):
                    self?.handleCloudKitError(error)
                }
            }
        }
        
        operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.updateStatus(.available)
                case .failure(let error):
                    self?.handleCloudKitError(error)
                }
            }
        }
        
        database.add(operation)
    }
    
    /// Met à jour / insère un enregistrement CloudKit dans SwiftData (WorkDay).
    @MainActor
    private func handleRecordChange(_ record: CKRecord, in context: ModelContext) {
        let recordID = record.recordID.recordName
        
        Task {
            let descriptor = FetchDescriptor<WorkDay>(
                predicate: #Predicate<WorkDay> { workDay in
                    workDay.cloudKitRecordID == recordID
                }
            )
            
            do {
                let workDays = try context.fetch(descriptor)
                let workDay = workDays.first ?? WorkDay(cloudKitRecordID: recordID)
                updateWorkDay(workDay, with: record)
                
                if workDays.isEmpty {
                    context.insert(workDay)
                }
                
                // Si "save()" est throws, alors "try".
                do {
                    try context.save()
                } catch {
                    print("Erreur lors de la sauvegarde (handleRecordChange): \(error)")
                }
                
            } catch {
                print("Erreur lors du fetch WorkDay: \(error)")
            }
        }
    }
    
    /// Fabrique un CKRecord à partir d'un `WorkDay`.
    private func createCloudKitRecord(from workDay: WorkDay) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: workDay.id.uuidString,
            zoneID: CKRecordZone.ID(zoneName: zoneName)
        )
        let record = CKRecord(recordType: "WorkDay", recordID: recordID)
        
        record["date"] = workDay.date as CKRecordValue
        if let startTime = workDay.startTime {
            record["startTime"] = startTime as CKRecordValue
        }
        if let endTime = workDay.endTime {
            record["endTime"] = endTime as CKRecordValue
        }
        record["breakDuration"] = workDay.breakDuration as CKRecordValue
        record["totalHours"] = workDay.totalHours as CKRecordValue
        record["overtimeSeconds"] = workDay.overtimeSeconds as CKRecordValue
        record["typeRawValue"] = workDay.typeRawValue as CKRecordValue
        if let note = workDay.note {
            record["note"] = note as CKRecordValue
        }
        record["bonusAmount"] = workDay.bonusAmount as CKRecordValue
        record["createdAt"] = workDay.createdAt as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue
        
        return record
    }
    
    /// Met à jour un `WorkDay` local avec les champs provenant d'un record CloudKit.
    private func updateWorkDay(_ workDay: WorkDay, with record: CKRecord) {
        workDay.date = record["date"] as? Date ?? Date()
        workDay.startTime = record["startTime"] as? Date
        workDay.endTime = record["endTime"] as? Date
        workDay.breakDuration = record["breakDuration"] as? TimeInterval ?? 3600
        workDay.totalHours = record["totalHours"] as? Double ?? 0
        workDay.overtimeSeconds = record["overtimeSeconds"] as? Int ?? 0
        workDay.typeRawValue = record["typeRawValue"] as? String ?? WorkDayType.work.rawValue
        workDay.note = record["note"] as? String
        workDay.bonusAmount = record["bonusAmount"] as? Double ?? 0
        workDay.cloudKitRecordID = record.recordID.recordName
        workDay.createdAt = record["createdAt"] as? Date ?? Date()
        workDay.modifiedAt = record["modifiedAt"] as? Date ?? Date()
        
        // Recalculer les heures si nécessaire
        if workDay.type.isWorkDay {
            workDay.calculateHours()
        }
    }
    
    /// Gère les erreurs CloudKit de façon centralisée (mise à jour de l'UI, etc.).
    @MainActor
    private func handleCloudKitError(_ error: Error) {
        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .zoneNotFound:
                setupSync()
                userMessage = "Configuration de la zone iCloud..."
            case .quotaExceeded:
                updateStatus(.unavailable)
                userMessage = "Quota iCloud dépassé"
            case .networkUnavailable:
                updateStatus(.unavailable)
                userMessage = "Réseau non disponible"
            case .serverRecordChanged:
                // Récupérer la version du serveur
                if let serverRecord = cloudError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                   let context = modelContext {
                    handleRecordChange(serverRecord, in: context)
                    userMessage = "Mise à jour avec la version du serveur"
                }
            default:
                userMessage = "Erreur iCloud: \(cloudError.localizedDescription)"
                updateStatus(.error(cloudError))
            }
        } else {
            userMessage = "Erreur: \(error.localizedDescription)"
            updateStatus(.error(error))
        }
    }
    
    /// Met à jour le statut iCloud local.
    @MainActor
    private func updateStatus(_ newStatus: CloudStatus) {
        self.iCloudStatus = newStatus
        if case .error(let error) = newStatus {
            self.lastError = error
        }
    }
    
    /// Notifié quand le compte iCloud change (déconnexion, etc.).
    @objc private func iCloudAccountChanged(_ notification: Notification) {
        checkiCloudStatus()
    }
    
    /// Notifié lors de modifications distantes (push notifications).
    @objc private func handleRemoteNotification(_ notification: Notification) {
        requestSync()
    }
    
    /// Ne vérifie le statut iCloud que toutes les 60 secondes au plus.
    private func shouldPerformStatusCheck() -> Bool {
        let interval = Date().timeIntervalSince(lastCheckDate)
        if interval > 60 {
            lastCheckDate = Date()
            return true
        }
        return false
    }
    
    /// Lance automatiquement une synchro si aucune synchro n'a encore été effectuée ou si aucun token n'est présent.
    private func performSyncIfNeeded() {
        guard iCloudStatus == .available else { return }
        if lastSyncDate == nil || lastChangeToken == nil {
            performSync()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Preview Support
extension CloudService {
    static var preview: CloudService {
        let service = CloudService()
        service.iCloudStatus = .available
        service.lastSyncDate = Date()
        return service
    }
    
    #if DEBUG
    func simulateSyncProgress(_ progress: Double) {
        self.syncProgress = progress
        self.iCloudStatus = .syncing(progress: progress)
    }
    
    func simulateError(_ error: Error) {
        Task { @MainActor in
            self.handleCloudKitError(error)
        }
    }
    #endif
}
