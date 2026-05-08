import Foundation
import CloudKit
import SwiftUI
import SwiftData
import Combine
import Network

@MainActor
@Observable
final class ModernCloudService {
    static let shared = ModernCloudService()

    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?
    private(set) var userMessage: String?

    private let containerIdentifier = "iCloud.jordan-payez.MyTimePro"
    private var cancellables = Set<AnyCancellable>()
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
            case .idle: return "Prêt"
            case .syncing(let progress): return "Vérification iCloud \(Int(progress * 100))%"
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
        NotificationCenter.default.publisher(for: NSNotification.Name.CKAccountChanged)
            .sink { [weak self] _ in
                Task { await self?.refreshICloudStatus() }
            }
            .store(in: &cancellables)
    }

    func refreshICloudStatus() async {
        syncStatus = .syncing(progress: 0.25)
        userMessage = "Vérification du compte iCloud..."

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
        userMessage = "La restauration est gérée automatiquement par iCloud."
    }

    func stopSync() {
        syncStatus = .idle
        userMessage = "Vérification arrêtée"
    }

    func resetCloudKitInitialization() {
        UserDefaults.standard.removeObject(forKey: "ckSyncEngineStateData")
        syncStatus = .idle
        userMessage = "État iCloud réinitialisé. Redémarrez l'application si nécessaire."
        AppLogger.info("État iCloud réinitialisé", category: AppLogger.cloudKit)
    }

    func deleteRecord(withID recordID: String) async {
        AppLogger.info("Suppression CloudKit manuelle ignorée: SwiftData synchronise les suppressions (\(recordID))", category: AppLogger.cloudKit)
    }

    private func apply(accountStatus status: CKAccountStatus) {
        switch status {
        case .available:
            syncStatus = .idle
            userMessage = "iCloud disponible. Les données sont synchronisées par SwiftData."
        case .noAccount:
            syncStatus = .offline
            userMessage = "Aucun compte iCloud configuré"
        case .restricted:
            syncStatus = .error(message: "Accès iCloud restreint")
            userMessage = "Accès iCloud restreint"
        case .couldNotDetermine:
            syncStatus = .error(message: "Statut iCloud indéterminé")
            userMessage = "Impossible de vérifier iCloud"
        case .temporarilyUnavailable:
            syncStatus = .offline
            userMessage = "iCloud temporairement indisponible"
        @unknown default:
            syncStatus = .error(message: "Statut iCloud inconnu")
            userMessage = "Statut iCloud inconnu"
        }
    }

    private func handleSyncError(_ error: Error) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                syncStatus = .offline
                userMessage = "Connexion réseau indisponible"
            case .notAuthenticated:
                syncStatus = .error(message: "Non connecté à iCloud")
                userMessage = "Connectez-vous à iCloud dans Réglages"
            case .quotaExceeded:
                syncStatus = .error(message: "Quota iCloud dépassé")
                userMessage = "Libérez de l'espace dans iCloud"
            default:
                syncStatus = .error(message: ckError.localizedDescription)
                userMessage = "Erreur: \(ckError.localizedDescription)"
            }
        } else {
            syncStatus = .failed(error: error)
            userMessage = "Erreur: \(error.localizedDescription)"
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
                    self.userMessage = "Hors ligne - iCloud reprendra automatiquement"
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
            return "Aucune connexion réseau disponible"
        case .accountUnavailable(let message):
            return message
        }
    }
}
