import Foundation
import CloudKit
import SwiftUI
import SwiftData

@MainActor
class CloudService: ObservableObject {
    static let shared = CloudService()

    // MARK: - Published Properties
    @Published private(set) var iCloudStatus: CloudStatus = .unknown {
        didSet {
            if iCloudStatus == .available && !isSetup {
                Task {
                    try? await setupSync()
                }
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
    private let iCloudIdentifier = "iCloud.jordan-payez.MyTimePro"
    private var isSubscribed = false
    private var isSetup = false
    private var isSyncing = false

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
        Task { await checkiCloudStatus() }
    }

    // MARK: - Public Methods
    @MainActor
    func requestSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        
        do {
            try await performSync()
        } catch {
            await handleCloudKitError(error)
        }
        isSyncing = false
    }

    // MARK: - Private Methods
    private func performSync() async throws {
        guard iCloudStatus == .available else { return }
        
        updateStatus(.syncing(progress: 0))

        let changedZoneIDs = try await fetchDatabaseChanges()
        
        for zoneID in changedZoneIDs {
            try await fetchZoneChanges(zoneID)
        }

        lastSyncDate = Date()
        updateStatus(.available)
    }
    
    private func fetchDatabaseChanges() async throws -> Set<CKRecordZone.ID> {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: lastChangeToken)
            operation.qualityOfService = .utility
            
            var zoneIDs = Set<CKRecordZone.ID>()
            
            operation.recordZoneWithIDChangedBlock = { zoneID in
                zoneIDs.insert(zoneID)
            }
            
            operation.changeTokenUpdatedBlock = { [weak self] token in
                Task { @MainActor in
                    self?.lastChangeToken = token
                }
            }
            
            operation.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: zoneIDs)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }

    private func setupSync() async throws {
        let zone = CKRecordZone(zoneName: "MyTimeProZone")
        try await database.save(zone)
        
        isSetup = true
        updateStatus(.available)
        
        try await setupSubscription()
        try await performSync()
    }

    private func setupSubscription() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "mytimepro-all-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await database.save(subscription)
        isSubscribed = true
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.checkiCloudStatus()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CKDatabaseDidReceiveChanges"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.requestSync()
            }
        }
    }

    private func fetchZoneChanges(_ zoneID: CKRecordZone.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])
            operation.qualityOfService = .utility

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
                    Task { @MainActor in
                        self?.lastChangeToken = data.serverChangeToken
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                    return
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func updateStatus(_ newStatus: CloudStatus) {
        iCloudStatus = newStatus
        if case .error(let error) = newStatus {
            lastError = error
        }
    }

    private func handleCloudKitError(_ error: Error) async {
        if let cloudError = error as? CKError {
            await MainActor.run {
                userMessage = "Erreur iCloud: \(cloudError.localizedDescription)"
                switch cloudError.code {
                case .quotaExceeded, .networkFailure, .networkUnavailable:
                    updateStatus(.unavailable)
                default:
                    updateStatus(.error(cloudError))
                }
            }
        } else {
            await MainActor.run {
                updateStatus(.error(error))
            }
        }
    }

    private func checkiCloudStatus() async {
        do {
            let accountStatus = try await container.accountStatus()
            await MainActor.run {
                switch accountStatus {
                case .available:
                    updateStatus(.available)
                    if !isSetup {
                        Task {
                            try? await self.setupSync()
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
}
