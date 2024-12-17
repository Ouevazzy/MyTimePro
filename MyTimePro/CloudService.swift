import Foundation
import CloudKit
import SwiftUI
import SwiftData

actor CloudService: ObservableObject {
    static let shared = CloudService()

    // MARK: - Published Properties
    @MainActor @Published private(set) var iCloudStatus: CloudStatus = .unknown {
        didSet {
            if iCloudStatus == .available && !isSetup {
                Task {
                    try? await setupSync()
                }
            }
        }
    }
    @MainActor @Published private(set) var lastSyncDate: Date?
    @MainActor @Published private(set) var syncProgress: Double = 0
    @MainActor @Published private(set) var lastError: Error?
    @MainActor @Published var userMessage: String?

    // MARK: - Private Properties
    private let container: CKContainer
    private let database: CKDatabase
    private let iCloudIdentifier = "iCloud.jordan-payez.MyTimePro"
    private var isSubscribed = false
    private var isSetup = false
    private var isSyncing = false
    private var lastCheckDate: Date = .distantPast
    private var syncQueue = DispatchQueue(label: "com.mytimepro.sync", qos: .utility)

    // MARK: - CloudKit Properties
    private var lastChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.data(forKey: "lastChangeToken"),
                  let token = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: CKServerChangeToken.self,
                    from: tokenData
                  ) else {
                return nil
            }
            return token
        }
        set {
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
               ) {
                UserDefaults.standard.set(data, forKey: "lastChangeToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastChangeToken")
            }
        }
    }

    // MARK: - Initialization
    private init() {
        container = CKContainer(identifier: iCloudIdentifier)
        database = container.privateCloudDatabase
        setupNotifications()
        checkiCloudStatus()
    }

    // MARK: - Public Methods
    @MainActor
    func requestSync() {
        guard !isSyncing else { return }
        isSyncing = true
        
        Task {
            do {
                try await performSync()
            } catch {
                await handleCloudKitError(error)
            }
            isSyncing = false
        }
    }

    // MARK: - Private Methods - Setup
    private func setupSync() async throws {
        let zone = CKRecordZone(zoneName: "MyTimeProZone")
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .utility

        try await database.add(operation)
        
        await MainActor.run {
            isSetup = true
            updateStatus(.available)
        }
        
        try await setupSubscription()
        try await performSync()
    }

    private func setupSubscription() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        operation.qualityOfService = .utility

        try await database.add(operation)
        isSubscribed = true
    }

    // MARK: - Private Methods - Sync
    private func performSync() async throws {
        guard await iCloudStatus == .available else { return }
        
        await MainActor.run {
            updateStatus(.syncing(progress: 0))
        }

        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: lastChangeToken)
        operation.qualityOfService = .utility
        
        let changedZoneIDs = await withCheckedContinuation { continuation in
            var zoneIDs = Set<CKRecordZone.ID>()
            
            operation.recordZoneWithIDChangedBlock = { zoneID in
                zoneIDs.insert(zoneID)
            }
            
            operation.changeTokenUpdatedBlock = { [weak self] token in
                self?.lastChangeToken = token
            }
            
            operation.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: zoneIDs)
                case .failure(let error):
                    continuation.resume(returning: [])
                    print("Error fetching database changes: \(error)")
                }
            }
            
            database.add(operation)
        }

        // Fetch changes for each zone
        for zoneID in changedZoneIDs {
            try await fetchZoneChanges(zoneID)
        }

        await MainActor.run {
            lastSyncDate = Date()
            updateStatus(.available)
        }
    }

    private func fetchZoneChanges(_ zoneID: CKRecordZone.ID) async throws {
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])
        operation.qualityOfService = .utility

        await withCheckedContinuation { continuation in
            operation.recordWasChangedBlock = { record, _ in
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DataDidChange"),
                        object: nil,
                        userInfo: ["record": record]
                    )
                }
            }

            operation.recordZoneFetchResultBlock = { [weak self] zoneID, result in
                switch result {
                case .success(let data):
                    self?.lastChangeToken = data.serverChangeToken
                case .failure(let error):
                    print("Error fetching zone changes: \(error)")
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                continuation.resume()
            }

            database.add(operation)
        }
    }

    // MARK: - Private Methods - Status & Error Handling
    @MainActor
    private func updateStatus(_ newStatus: CloudStatus) {
        iCloudStatus = newStatus
        if case .error(let error) = newStatus {
            lastError = error
        }
    }

    @MainActor
    private func handleCloudKitError(_ error: Error) {
        if let cloudError = error as? CKError {
            userMessage = "Erreur iCloud: \(cloudError.localizedDescription)"
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

    private func checkiCloudStatus() {
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        updateStatus(.available)
                        if !isSetup {
                            Task {
                                try? await setupSync()
                            }
                        }
                    case .restricted:
                        updateStatus(.restricted)
                    case .noAccount:
                        updateStatus(.unavailable)
                    case .couldNotDetermine, .temporarilyUnavailable:
                        updateStatus(.unknown)
                    @unknown default:
                        updateStatus(.unknown)
                    }
                }
            } catch {
                await handleCloudKitError(error)
            }
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

    @objc private func iCloudAccountChanged() {
        checkiCloudStatus()
    }

    @objc private func handleRemoteNotification() {
        requestSync()
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

    // MARK: - Error Types
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

    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
