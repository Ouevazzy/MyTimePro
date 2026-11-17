import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import WorkTimer

private final class CommerceFixtureBundle: NSObject {}

@Suite("WorkTimer Pro — transactions StoreKit locales", .serialized)
@MainActor
struct StoreManagerCommerceTests {
    @Test("Catalogue, achat, restauration, expiration, remboursement et approbation parentale")
    func localPurchaseLifecycle() async throws {
        print("COMMERCE: configuration")
        let fixture = try #require(Bundle(for: CommerceFixtureBundle.self)
            .url(forResource: "StoreKitCommerceFixture", withExtension: "json"))
        let configuration = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkTimer-Commerce-\(UUID().uuidString).storekit")
        try Data(contentsOf: fixture).write(to: configuration)
        print("COMMERCE: creating session")
        let session = try SKTestSession(contentsOf: configuration)
        print("COMMERCE: resetting session")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer {
            session.clearTransactions()
            print("COMMERCE: resetting session")
        session.resetToDefaultState()
            try? FileManager.default.removeItem(at: configuration)
        }

        print("COMMERCE: loading products")
        let store = StoreManager.shared
        await store.loadProducts()
        #expect(Set(store.products.map(\.id)) == Set([
            StoreManager.monthlyID, StoreManager.annualID, StoreManager.lifetimeID
        ]))
        await expectEntitlement(false, store: store)
        let monthly = try #require(store.products.first { $0.id == StoreManager.monthlyID })
        let annual = try #require(store.products.first { $0.id == StoreManager.annualID })
        let lifetime = try #require(store.products.first { $0.id == StoreManager.lifetimeID })

        print("COMMERCE: purchasing monthly")
        let monthlyResult = try await store.purchase(monthly)
        guard case .success = monthlyResult else {
            Issue.record("L’achat mensuel local doit réussir.")
            return
        }
        await expectEntitlement(true, store: store)
        #expect(store.activeProductID == monthly.id)
        try session.expireSubscription(productIdentifier: monthly.id)
        try await AppStore.sync()
        await expectEntitlement(false, store: store)

        session.clearTransactions()
        print("COMMERCE: purchasing annual")
        let annualResult = try await store.purchase(annual)
        guard case .success = annualResult else {
            Issue.record("L’achat annuel local doit réussir.")
            return
        }
        await expectEntitlement(true, store: store)
        print("COMMERCE: restoring annual")
        await store.restorePurchases()
        #expect(store.isPro)
        #expect(store.activeProductID == annual.id)
        try session.expireSubscription(productIdentifier: annual.id)
        try await AppStore.sync()
        await expectEntitlement(false, store: store)

        session.clearTransactions()
        print("COMMERCE: purchasing lifetime")
        let lifetimeResult = try await store.purchase(lifetime)
        guard case .success = lifetimeResult else {
            Issue.record("L’achat à vie local doit réussir.")
            return
        }
        await expectEntitlement(true, store: store)
        #expect(store.activeProductID == lifetime.id)
        let lifetimeTransaction = try #require(session.allTransactions()
            .first { $0.productIdentifier == lifetime.id })
        try session.refundTransaction(identifier: lifetimeTransaction.identifier)
        await expectEntitlement(false, store: store)

        session.clearTransactions()
        session.askToBuyEnabled = true
        print("COMMERCE: ask to buy")
        let pendingResult = try await store.purchase(monthly)
        guard case .pending = pendingResult else {
            Issue.record("Un achat nécessitant une approbation doit rester en attente.")
            return
        }
        await expectEntitlement(false, store: store)
        let pendingTransaction = try #require(session.allTransactions()
            .first { $0.productIdentifier == monthly.id })
        try session.approveAskToBuyTransaction(identifier: pendingTransaction.identifier)
        await expectEntitlement(true, store: store)
    }

    private func expectEntitlement(_ expected: Bool, store: StoreManager) async {
        for _ in 0..<50 {
            await store.refreshPurchaseStatus()
            if store.isPro == expected { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("COMMERCE: unexpected entitlement, active=\(String(describing: store.activeProductID)), now=\(Date())")
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                print("COMMERCE: entitlement \(transaction.productID), expiry=\(String(describing: transaction.expirationDate)), revoked=\(String(describing: transaction.revocationDate))")
            }
        }
        #expect(store.isPro == expected)
    }
}
