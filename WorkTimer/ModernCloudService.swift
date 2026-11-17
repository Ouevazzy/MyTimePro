import Foundation
import CloudKit
import SwiftUI
import SwiftData
import Network

@MainActor
@Observable
final class ModernCloudService {
    static let shared = ModernCloudService()

    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?
    private(set) var userMessage: String?

    private let containerIdentifier = "iCloud.jordan-payez.MyTimePro"
    private var accountChangedTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var isInitialized = false
    private let networkMonitor = NWPathMonitor()

    enum SyncStatus: Equatable {
        case idle
        case syncing(progress: Double)
        case error(message: String)
        case offline
        case failed(error: Error)

        var description: String {
            switch self {
            case .idle: return "cloud.status.ready".localized
            case .syncing(let progress): return "cloud.status.checking".localized(Int(progress * 100))
            case .error(let message): return "cloud.status.error".localized(message)
            case .offline: return "cloud.status.offline".localized
            case .failed(let error): return "cloud.status.failed".localized(error.localizedDescription)
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
            case (.idle, .idle), (.offline, .offline):
                return true
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

    private init() {
        setupNetworkMonitoring()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Diagnostic (TestFlight / App Store)

    /// Identifiant du conteneur CloudKit utilisé pour la synchronisation.
    var cloudKitContainerID: String { containerIdentifier }

    /// Environnement CloudKit ciblé par la build courante.
    /// Debug (Xcode) → Development ; TestFlight & App Store → Production.
    var cloudKitEnvironment: String {
        #if DEBUG
        return "Development"
        #else
        return "Production"
        #endif
    }

    /// CloudKit est-il réellement actif sur cette build ? (désactivé en Debug)
    var isCloudKitActive: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    func initialize() {
        guard !isInitialized else {
            Task { await refreshICloudStatus() }
            return
        }

        setupCloudKitNotifications()
        isInitialized = true
        Task { await refreshICloudStatus() }
    }

    private func setupCloudKitNotifications() {
        accountChangedTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await self?.refreshICloudStatus()
            }
        }
    }

    func refreshICloudStatus() async {
        syncStatus = .syncing(progress: 0.25)
        userMessage = "cloud.msg.checkingAccount".localized

        do {
            let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
            apply(accountStatus: status)
            lastSyncDate = Date()
        } catch {
            handleSyncError(error)
        }
    }

    func sendChanges() async throws {
        if let modelContext {
            try modelContext.save()
        }
        await refreshICloudStatus()

        if case .error(let message) = syncStatus {
            throw CloudServiceError.accountUnavailable(message)
        }
        if case .offline = syncStatus {
            throw CloudServiceError.noNetworkConnection
        }
    }

    func requestSync() {
        Task {
            do {
                try await sendChanges()
            } catch {
                AppLogger.error("iCloud status refresh failed", category: AppLogger.cloudKit, error: error)
            }
        }
    }

    func restoreFromCloud() async {
        await refreshICloudStatus()
        userMessage = "cloud.msg.restoreAutomatic".localized
    }

    func cleanupGhostEntries() async throws {
        guard let ctx = modelContext else { return }
        let count = try WorkDay.deleteGhostEntries(in: ctx)
        if count > 0 {
            AppLogger.info("\(count) entrée(s) fantôme(s) supprimée(s) en background", category: AppLogger.data)
        }
    }

    func stopSync() {
        syncStatus = .idle
        userMessage = "cloud.msg.stopped".localized
    }

    func resetCloudKitInitialization() {
        UserDefaults.standard.removeObject(forKey: "ckSyncEngineStateData")
        syncStatus = .idle
        userMessage = "cloud.msg.reset".localized
        AppLogger.info("État iCloud réinitialisé", category: AppLogger.cloudKit)
    }

    func deleteRecord(withID recordID: String) async {
        AppLogger.info("Suppression CloudKit manuelle ignorée: SwiftData synchronise les suppressions (\(recordID))", category: AppLogger.cloudKit)
    }

    private func apply(accountStatus status: CKAccountStatus) {
        switch status {
        case .available:
            syncStatus = .idle
            userMessage = "cloud.msg.available".localized
        case .noAccount:
            syncStatus = .offline
            userMessage = "cloud.msg.noAccount".localized
        case .restricted:
            syncStatus = .error(message: "cloud.msg.restricted".localized)
            userMessage = "cloud.msg.restricted".localized
        case .couldNotDetermine:
            syncStatus = .error(message: "cloud.msg.undetermined".localized)
            userMessage = "cloud.msg.cannotCheck".localized
        case .temporarilyUnavailable:
            syncStatus = .offline
            userMessage = "cloud.msg.temporarilyUnavailable".localized
        @unknown default:
            syncStatus = .error(message: "cloud.msg.unknown".localized)
            userMessage = "cloud.msg.unknown".localized
        }
    }

    private func handleSyncError(_ error: Error) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                syncStatus = .offline
                userMessage = "cloud.msg.networkUnavailable".localized
            case .notAuthenticated:
                syncStatus = .error(message: "cloud.msg.notAuthenticated".localized)
                userMessage = "cloud.msg.signIn".localized
            case .quotaExceeded:
                syncStatus = .error(message: "cloud.msg.quotaExceeded".localized)
                userMessage = "cloud.msg.freeSpace".localized
            default:
                syncStatus = .error(message: ckError.localizedDescription)
                userMessage = "cloud.status.error".localized(ckError.localizedDescription)
            }
        } else {
            syncStatus = .failed(error: error)
            userMessage = "cloud.status.error".localized(error.localizedDescription)
        }
    }

    private func setupNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                if path.status == .satisfied {
                    if self.syncStatus == .offline {
                        await self.refreshICloudStatus()
                    }
                } else {
                    self.syncStatus = .offline
                    self.userMessage = "cloud.msg.offlineResume".localized
                }
            }
        }
        networkMonitor.start(queue: queue)
    }

    deinit {
        networkMonitor.cancel()
    }
}

enum CloudServiceError: LocalizedError {
    case noNetworkConnection
    case accountUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .noNetworkConnection:
            return "cloud.msg.noNetwork".localized
        case .accountUnavailable(let message):
            return message
        }
    }
}
