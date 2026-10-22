#if canImport(StoreKitTest) && canImport(StoreKit) && !SWIFT_PACKAGE
import Foundation
import StoreKit
import StoreKitTest
import XCTest
@testable import OnlineNow

/// Local StoreKit checks run with the bundled catalog; sandbox/product approval
/// must still be verified separately before an App Store release.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TippingStoreKitTests: XCTestCase {
    func testInjectedPurchaseCancellationDoesNotCreditSupportOrShowFailure() async throws {
        try await withLocalProduct { product, manager, session in
            var calls = 0
            manager.errorMessage = "An earlier payment failed"
            let cancelled = await manager.purchase(product, performPurchase: { requested in
                calls += 1
                XCTAssertEqual(requested.id, product.id)
                XCTAssertTrue(manager.isPurchasing)
                return .userCancelled
            })
            XCTAssertFalse(cancelled)
            XCTAssertNil(manager.errorMessage)
            XCTAssertFalse(manager.isPurchasing)
            XCTAssertFalse(manager.isPending)
            XCTAssertEqual(manager.tipCount, 0)

            let thrownCancellation = await manager.purchase(product, performPurchase: { requested in
                calls += 1
                XCTAssertEqual(requested.id, product.id)
                throw StoreKitError.userCancelled
            })
            XCTAssertFalse(thrownCancellation)
            XCTAssertNil(manager.errorMessage)
            XCTAssertFalse(manager.isPurchasing)
            XCTAssertFalse(manager.isPending)
            XCTAssertEqual(manager.tipCount, 0)
            XCTAssertEqual(calls, 2)
            XCTAssertTrue(session.allTransactions().isEmpty)
        }
    }

    func testInjectedPendingPurchaseBlocksAnotherPurchaseWithoutCreditingSupport() async throws {
        try await withLocalProduct { product, manager, session in
            var calls = 0
            let pending = await manager.purchase(product, performPurchase: { requested in
                calls += 1
                XCTAssertEqual(requested.id, product.id)
                return .pending
            })
            XCTAssertFalse(pending)
            XCTAssertTrue(manager.isPending)
            XCTAssertFalse(manager.isPurchasing)
            XCTAssertNil(manager.errorMessage)
            XCTAssertEqual(manager.tipCount, 0)
            let repeated = await manager.purchase(product, performPurchase: { _ in
                calls += 1
                return .userCancelled
            })
            XCTAssertFalse(repeated)
            XCTAssertEqual(calls, 1, "Pending approval must prevent another purchase action")
            XCTAssertTrue(session.allTransactions().isEmpty)
        }
    }

    func testInjectedUnknownFailureRemainsVisibleAndNextAttemptCanProceed() async throws {
        try await withLocalProduct { product, manager, session in
            var calls = 0
            let failed = await manager.purchase(product, performPurchase: { requested in
                calls += 1
                XCTAssertEqual(requested.id, product.id)
                throw StoreKitError.unknown
            })
            XCTAssertFalse(failed)
            XCTAssertNotNil(manager.errorMessage, "An unknown store error must remain a visible failure")
            XCTAssertFalse(manager.isPurchasing)
            XCTAssertFalse(manager.isPending)
            XCTAssertEqual(manager.tipCount, 0)
            let retry = await manager.purchase(product, performPurchase: { _ in
                calls += 1
                return .userCancelled
            })
            XCTAssertFalse(retry)
            XCTAssertNil(manager.errorMessage)
            XCTAssertFalse(manager.isPurchasing)
            XCTAssertEqual(manager.tipCount, 0)
            XCTAssertEqual(calls, 2)
            XCTAssertTrue(session.allTransactions().isEmpty)
        }
    }

    func testRepeatConsumableTransactionsAndUnfinishedRecovery() async throws {
        executionTimeAllowance = 60
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }

        let suite = "OnlineNow.StoreKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let productID = "onlinenow.gdemay"
        // Register the local catalog with StoreKit before outside-app purchases,
        // without starting an application transaction listener or granting tips.
        let products = try await Product.products(for: [productID])
        let product = try XCTUnwrap(products.first { $0.id == productID })
        XCTAssertEqual(product.type, .consumable)
        let beforeRecovery = TippingManager(defaults: defaults, startsStoreKit: false)
        XCTAssertEqual(beforeRecovery.tipCount, 0)

        // Simulate an actual StoreKit purchase while the app is not listening.
        // This outside-app API does not require the unit host to present payment
        // UI. Purchases from the app, including Ask to Buy, run in the UI suite.
        let firstPurchase = try await session.buyProduct(identifier: productID)
        let unfinished = session.allTransactions()
        XCTAssertEqual(unfinished.count, 1)
        XCTAssertTrue(unfinished.allSatisfy { $0.state == .purchased })
        XCTAssertEqual(beforeRecovery.tipCount, 0)

        // The test-session purchase API and StoreKit 2 receipt publication are
        // asynchronous. Establish a real, verified unfinished receipt before
        // testing startup recovery; a missing receipt is a fixture setup failure.
        // Reading this sequence must not finish the purchase or grant support.
        let receiptReady = try await waitUntil(timeout: 10) {
            for await result in Transaction.unfinished {
                if case .verified(let transaction) = result,
                   transaction.id == firstPurchase.id,
                   transaction.productID == productID,
                   transaction.productType == .consumable {
                    return true
                }
            }
            return false
        }
        XCTAssertTrue(receiptReady, "The local StoreKit fixture did not publish the verified unfinished consumable before recovery started")
        guard receiptReady else { return }

        let manager = TippingManager(defaults: defaults, startsStoreKit: true)
        let recovered = try await waitUntil(timeout: 10) {
            // Products load only after the unfinished-transaction pass ends.
            manager.tipCount == 1 && !manager.products.isEmpty && !manager.isLoading
        }
        XCTAssertTrue(recovered, "The unfinished consumable was not recovered")
        // Preserve the recovery failure instead of cascading into a second
        // same-SKU purchase while its first consumable is still unfinished.
        guard recovered else { return }
        XCTAssertEqual(manager.tipCount, 1)
        XCTAssertTrue(manager.isSupporter)
        XCTAssertEqual(manager.products.first?.id, productID)
        XCTAssertEqual(manager.products.first?.type, .consumable)

        // Recording support precedes transaction.finish(). If the live update
        // listener delivers the receipt, the published count alone is not a
        // finish barrier for another purchase of this consumable.
        let firstFinished = try await waitUntil(timeout: 10) {
            for await result in Transaction.unfinished {
                switch result {
                case .verified(let transaction), .unverified(let transaction, _):
                    if transaction.id == firstPurchase.id { return false }
                }
            }
            return true
        }
        XCTAssertTrue(firstFinished, "The recovered consumable must finish before purchasing the same tip again")
        guard firstFinished else { return }

        // StoreKit permits another consumable of this SKU after the first has
        // finished. This purchase exercises Transaction.updates independently
        // of the completed startup recovery pass.
        let secondPurchase = try await session.buyProduct(identifier: productID)
        XCTAssertNotEqual(firstPurchase.id, secondPurchase.id)
        let updated = try await waitUntil(timeout: 10) { manager.tipCount == 2 }
        XCTAssertTrue(updated, "The new consumable was not delivered through Transaction.updates")
        XCTAssertEqual(manager.tipCount, 2)
        let transactions = session.allTransactions()
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(Set(transactions.map(\.identifier)).count, 2)
        let purchaseIDs = Set([firstPurchase.id, secondPurchase.id])
        let finished = try await waitUntil(timeout: 10) {
            for await result in Transaction.unfinished {
                switch result {
                case .verified(let transaction), .unverified(let transaction, _):
                    if purchaseIDs.contains(transaction.id) { return false }
                }
            }
            return true
        }
        XCTAssertTrue(finished, "Both consumables must finish after their recorded support is saved")
        let restarted = TippingManager(defaults: defaults, startsStoreKit: false)
        XCTAssertEqual(restarted.tipCount, 2, "Recovered and live transactions must persist exactly once")
    }

    private func withLocalProduct(
        _ test: @MainActor (Product, TippingManager, SKTestSession) async throws -> Void
    ) async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let suite = "OnlineNow.PurchaseActionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let products = try await Product.products(for: ["onlinenow.gdemay"])
        let product = try XCTUnwrap(products.first { $0.id == "onlinenow.gdemay" })
        XCTAssertEqual(product.type, .consumable)
        let manager = TippingManager(defaults: defaults, startsStoreKit: false)
        try await test(product, manager, session)
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () async -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            // StoreKit receipts are asynchronous snapshots. Preserve the first
            // successful observation instead of asking a second snapshot to
            // repeat it after the polling loop has already succeeded.
            if await condition() { return true }
            guard Date() < deadline else { return false }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
#endif
