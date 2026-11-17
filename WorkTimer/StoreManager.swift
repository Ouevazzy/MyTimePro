import Foundation
import StoreKit

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    /// Loading state of the App Store products, so the paywall can distinguish
    /// "still loading" from "failed to load" and offer a retry path.
    enum ProductsState {
        case loading
        case loaded
        case failed
    }

    /// Outcome of a purchase attempt, surfaced to the UI so pending purchases
    /// (e.g. Ask to Buy / SCA approval) get explicit feedback instead of looking
    /// like a silent failure.
    enum PurchaseOutcome {
        case success
        case pending
        case cancelled
        case verificationFailed
    }

    private(set) var isPro = false
    private(set) var activeProductID: String? = nil
    private(set) var products: [Product] = []
    private(set) var productsState: ProductsState = .loading

    static let monthlyID  = "com.worktimer.pro.subscription.monthly"
    static let annualID   = "com.worktimer.pro.annual"
    static let lifetimeID = "com.worktimer.pro.lifetime"

    private let allIDs = [StoreManager.monthlyID, StoreManager.annualID, StoreManager.lifetimeID]
    private var transactionListener: Task<Void, Never>?

    private init() {
        #if DEBUG
        applyDebugProUnlockIfRequested()
        #endif

        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProducts()
            await refreshPurchaseStatus()
        }
    }


    func loadProducts() async {
        #if DEBUG
        guard !isDebugProUnlockRequested else {
            productsState = .loaded
            return
        }
        #endif

        productsState = .loading
        do {
            let fetched = try await Product.products(for: allIDs)
            products = fetched.sorted {
                (allIDs.firstIndex(of: $0.id) ?? 0) < (allIDs.firstIndex(of: $1.id) ?? 0)
            }
            // Une liste vide (IDs inconnus, config StoreKit absente) est un échec
            // du point de vue de l'utilisateur : rien à acheter.
            productsState = fetched.isEmpty ? .failed : .loaded
        } catch {
            productsState = .failed
            AppLogger.error("StoreKit: chargement produits échoué", category: AppLogger.data, error: error)
        }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            return await handle(verification) ? .success : .verificationFailed
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            AppLogger.error("StoreKit: restauration échouée", category: AppLogger.data, error: error)
        }
    }

    func refreshAfterExternalRedemption() async {
        await refreshPurchaseStatus()
    }

    func refreshPurchaseStatus() async {
        #if DEBUG
        guard !isDebugProUnlockRequested else {
            applyDebugProUnlockIfRequested()
            return
        }
        #endif

        var hasPro = false
        var foundID: String? = nil
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, allIDs.contains(tx.productID) {
                hasPro = true
                foundID = tx.productID
                if tx.productID == StoreManager.lifetimeID {
                    break
                }
            }
        }
        isPro = hasPro
        activeProductID = foundID
    }

    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else {
            AppLogger.warning("StoreKit: transaction non vérifiée ignorée", category: AppLogger.data)
            return false
        }
        await refreshPurchaseStatus()
        await transaction.finish()
        return true
    }

    #if DEBUG
    private var isDebugProUnlockRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-WorkTimerDebugProUnlocked")
    }

    private func applyDebugProUnlockIfRequested() {
        guard isDebugProUnlockRequested else { return }
        isPro = true
        activeProductID = "debug.pro"
    }
    #endif
}
