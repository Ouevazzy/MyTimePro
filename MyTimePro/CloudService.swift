import CloudKit
import SwiftUI
import SwiftData

class CloudService: ObservableObject {
    static let shared = CloudService()

    // MARK: - Published Properties
    @Published private(set) var iCloudStatus: CloudStatus = .unknown {
        didSet {
            if iCloudStatus == .available && !isSetup {
                setupSync()
            } else if iCloudStatus == .available {
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
    private let iCloudIdentifier = \"iCloud.jordan-payez.MyTimePro\"
    private var isSubscribed = false
    private var isSetup = false
    private var lastCheckDate: Date = .distantPast

    // MARK: - Initialization
    private init() {
        container = CKContainer(identifier: iCloudIdentifier)
        database = container.privateCloudDatabase
        setupNotifications()
        checkiCloudStatus()
    }

    // MARK: - Public Methods
    func monitorSyncStatus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncChange),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }

    func checkiCloudStatus() {
        print(\"Checking container:\", container.containerIdentifier ?? \"No identifier\")
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

    // MARK: - Private Methods
    private func setupSync() {
        checkiCloudStatus()
        setupSubscription()
    }

    private func setupSubscription() {
        guard !isSubscribed else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: \"all-changes\")
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
                    self?.handleCloudKitError(error)
                }
            }
        }

        operation.qualityOfService = .utility
        database.add(operation)
    }

    @objc private func handleSyncChange(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else { return }
            
        switch event.type {
        case .setup: 
            updateStatus(.syncing(progress: 0))
        case .import:
            updateStatus(.syncing(progress: 0.5))
        case .export:
            updateStatus(.syncing(progress: 0.8))
        default:
            if event.succeeded {
                updateStatus(.available)
            } else if let error = event.error {
                handleCloudKitError(error)
            }
        }
    }

    private func performSyncIfNeeded() {
        guard iCloudStatus.isAvailable else { return }
        if lastSyncDate == nil {
            updateStatus(.syncing(progress: 0))
        }
    }

    private func shouldPerformStatusCheck() -> Bool {
        let interval = Date().timeIntervalSince(lastCheckDate)
        return interval > 60
    }

    private func handleCloudKitError(_ error: Error) {
        if let cloudError = error as? CKError {
            DispatchQueue.main.async {
                switch cloudError.code {
                case .quotaExceeded:
                    self.userMessage = \"Espace iCloud insuffisant\"
                case .networkFailure, .networkUnavailable:
                    self.userMessage = \"Problème de connexion réseau\"
                case .notAuthenticated:
                    self.userMessage = \"Veuillez vous connecter à iCloud\"
                default:
                    self.userMessage = cloudError.localizedDescription
                }
                
                switch cloudError.code {
                case .quotaExceeded, .networkFailure, .networkUnavailable:
                    self.updateStatus(.unavailable)
                default:
                    self.updateStatus(.error(cloudError))
                }
            }
        } else {
            updateStatus(.error(error))
        }
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

    // MARK: - Types
    enum CloudStatus: Equatable {
        case unknown
        case available
        case unavailable
        case restricted
        case syncing(progress: Double)
        case error(Error)

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
                return \"Vérification...\"
            case .available:
                return \"Synchronisé\"
            case .unavailable:
                return \"iCloud non disponible\"
            case .restricted:
                return \"Accès restreint\"
            case .syncing(let progress):
                return \"Synchronisation \\(Int(progress * 100))%\"
            case .error(let error):
                return \"Erreur: \\(error.localizedDescription)\"
            }
        }

        var iconName: String {
            switch self {
            case .unknown: return \"questionmark.circle\"
            case .available: return \"checkmark.circle\"
            case .unavailable: return \"xmark.circle\"
            case .restricted: return \"exclamationmark.triangle\"
            case .syncing: return \"arrow.triangle.2.circlepath\"
            case .error: return \"exclamationmark.circle\"
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

    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}`,
  `message`: `Mise à jour de CloudService avec le bon identifiant et les améliorations de synchronisation`
}
