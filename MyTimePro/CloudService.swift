
import Foundation
import CloudKit
import SwiftUI

class CloudService: ObservableObject {
    static let shared = CloudService()

    // MARK: - Published Properties
    @Published private(set) var iCloudStatus: CloudStatus = .unknown {
        didSet {
            if iCloudStatus == .available && !isSetup {
                // Quand iCloud devient disponible et que le setup n'est pas fait, on le fait
                setupSync()
            } else if iCloudStatus == .available {
                // Si iCloud est déjà disponible et setup fait, on effectue une synchro initiale si nécessaire
                performSyncIfNeeded()
            }
        }
    }
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncProgress: Double = 0
    @Published private(set) var lastError: Error?
    @Published var userMessage: String?

    // MARK: - Private Properties
    private let container: CKContainer
    private let database: CKDatabase
    private let iCloudIdentifier = "iCloud.jordan-payez.WorkTimer"
    private var isSubscribed = false
    private var isSetup = false
    private var lastCheckDate: Date = .distantPast
    // Timer supprimé, on synchronise à la demande ou aux changements d'état iCloud
    // private var syncTimer: Timer?

    private var lastChangeToken: CKServerChangeToken? {
        didSet {
            if let token = lastChangeToken,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "lastChangeToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastChangeToken")
            }
        }
    }

    // MARK: - Types
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

        var isAvailable: Bool {
            switch self {
            case .available, .syncing:
                return true
            default:
                return false
            }
        }

        var description: String {
            switch self {
            case .unknown:
                return "Vérification..."
            case .available:
                return "Synchronisé"
            case .unavailable:
                return "iCloud non disponible"
            case .restricted:
                return "Accès restreint"
            case .syncing(let progress):
                return "Synchronisation \(Int(progress * 100))%"
            case .error(let error):
                return "Erreur: \(error.localizedDescription)"
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
    }

    enum CloudError: LocalizedError {
        case iCloudNotAvailable
        case syncFailed(Error)
        case dataNotFound
        case subscriptionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .iCloudNotAvailable:
                return "iCloud n'est pas disponible"
            case .syncFailed(let error):
                return "Échec de synchronisation: \(error.localizedDescription)"
            case .dataNotFound:
                return "Données non trouvées"
            case .subscriptionFailed(let error):
                return "Échec de l'abonnement: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        container = CKContainer(identifier: iCloudIdentifier)
        database = container.privateCloudDatabase

        if let tokenData = UserDefaults.standard.data(forKey: "lastChangeToken") {
            lastChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }

        setupNotifications()
        checkiCloudStatus()
        // Pas de timer ici. La synchro est déclenchée par les changements d'état iCloud ou manuellement.
    }

    // MARK: - Public Methods
    func checkiCloudStatus() {
        guard shouldPerformStatusCheck() else { return }
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
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

    func requestSync() {
        guard iCloudStatus.isAvailable else { return }
        performSync()
    }

    // MARK: - Private Methods
    private func shouldPerformStatusCheck() -> Bool {
        let interval = Date().timeIntervalSince(lastCheckDate)
        return interval > 60 // Vérifie le statut iCloud au plus toutes les 60 secondes
    }

    private func handleCloudKitError(_ error: Error) {
        if let cloudError = error as? CKError {
            DispatchQueue.main.async {
                self.userMessage = "Erreur iCloud: \(cloudError.localizedDescription)"
            }
            switch cloudError.code {
            case .quotaExceeded, .networkFailure, .networkUnavailable:
                updateStatus(.unavailable)
            default:
                updateStatus(.error(cloudError))
            }
        } else {
            updateStatus(.error(error))
        }
    }

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

    private func setupSync() {
        let zone = CKRecordZone(zoneName: "WorkTimeZone")
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)

        operation.modifyRecordZonesResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isSetup = true
                    self?.updateStatus(.available)
                    self?.setupSubscription()
                    // Une fois le setup effectué, on déclenche une synchro initiale
                    self?.performSyncIfNeeded()
                case .failure(let error):
                    self?.updateStatus(.error(CloudError.syncFailed(error)))
                }
            }
        }

        operation.qualityOfService = .utility
        database.add(operation)
    }

    private func performSyncIfNeeded() {
        guard iCloudStatus.isAvailable else { return }
        // Si aucune synchro n'a été faite ou si c'est une nouvelle installation (pas de token), on fait une synchro complète.
        if lastSyncDate == nil || lastChangeToken == nil {
            performSync()
        }
    }

    private func setupSubscription() {
        guard !isSubscribed else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: "all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: []
        )

        operation.modifySubscriptionsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isSubscribed = true
                    self?.lastSyncDate = Date()
                case .failure(let error):
                    self?.updateStatus(.error(CloudError.subscriptionFailed(error)))
                }
            }
        }

        operation.qualityOfService = .utility
        database.add(operation)
    }

    private func performSync() {
        updateStatus(.syncing(progress: 0))

        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: lastChangeToken)

        operation.changeTokenUpdatedBlock = { [weak self] token in
            self?.lastChangeToken = token
        }

        operation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
            self?.fetchZoneChanges(zoneID)
        }

        operation.fetchDatabaseChangesResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.lastSyncDate = Date()
                    self?.updateStatus(.available)
                case .failure(let error):
                    self?.updateStatus(.error(CloudError.syncFailed(error)))
                }
            }
        }

        operation.qualityOfService = .utility
        database.add(operation)
    }

    private func fetchZoneChanges(_ zoneID: CKRecordZone.ID) {
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )

        operation.recordWasChangedBlock = { record, _ in
            DispatchQueue.main.async {
                // L'application doit écouter "DataDidChange" et mettre à jour sa base locale en conséquence
                NotificationCenter.default.post(
                    name: NSNotification.Name("DataDidChange"),
                    object: nil,
                    userInfo: ["record": record]
                )
            }
        }

        operation.recordZoneFetchResultBlock = { [weak self] zoneID, result in
            switch result {
            case .success(let resultData):
                self?.lastChangeToken = resultData.serverChangeToken
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.handleCloudKitError(error)
                }
            }
        }

        operation.qualityOfService = .utility
        database.add(operation)
    }

    private func updateStatus(_ newStatus: CloudStatus) {
        DispatchQueue.main.async {
            self.iCloudStatus = newStatus
            if case .error(let error) = newStatus {
                self.lastError = error
            }
        }
    }

    // MARK: - Notification Handlers
    @objc private func iCloudAccountChanged(_ notification: Notification) {
        checkiCloudStatus()
    }

    @objc private func handleRemoteNotification(_ notification: Notification) {
        requestSync()
    }

    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
// Dans CloudService.swift, ajoutez ces logs
func checkiCloudStatus() {
    let container = CKContainer(identifier: "iCloud.jordan-payez.worktimer")
    print("Checking container:", container.containerIdentifier ?? "No identifier")
    
    container.accountStatus { status, error in
        if let error = error {
            print("Error checking account status:", error)
            return
        }
        print("Account status:", status.rawValue)
    }
}
