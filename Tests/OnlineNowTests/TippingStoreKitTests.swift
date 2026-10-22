#if canImport(StoreKitTest) && canImport(StoreKit) && !SWIFT_PACKAGE
import Foundation
import StoreKit
import StoreKitTest
import XCTest
@testable import OnlineNow

/// Local StoreKit checks run with the bundled catalog; sandbox/product approval
/// must still be verified separately before an App Store release.
@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class TippingStoreKitTests: XCTestCase {
    func testRepeatConsumablePurchaseAndUnfinishedRecovery() async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }

        let suite = "OnlineNow.StoreKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = TippingManager(defaults: defaults, startsStoreKit: false)
        await manager.loadProducts()
        let product = try XCTUnwrap(manager.products.first)
        XCTAssertEqual(product.id, "onlinenow.gdemay")
        XCTAssertEqual(product.type, .consumable)

        let firstSuccess = await manager.purchase(product)
        XCTAssertTrue(firstSuccess)
        let secondSuccess = await manager.purchase(product)
        XCTAssertTrue(secondSuccess)
        XCTAssertEqual(manager.tipCount, 2)

        // Create a purchase while no manager listens, simulating termination
        // between App Store confirmation and local fulfillment.
        _ = try await session.buyProduct(identifier: product.id)
        let recovered = TippingManager(defaults: defaults, startsStoreKit: true)
        let deadline = Date().addingTimeInterval(5)
        while recovered.tipCount < 3, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(recovered.tipCount, 3)
    }

    func testAskToBuyApprovalIsDeliveredOnce() async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }

        let suite = "OnlineNow.AskToBuyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = TippingManager(defaults: defaults, startsStoreKit: true)
        let loading = Task { await manager.loadProducts() }
        defer { loading.cancel() }
        let productsLoaded = try await waitUntil(timeout: 10) { !manager.products.isEmpty }
        XCTAssertTrue(productsLoaded, "The local StoreKit catalog did not load: \(manager.errorMessage ?? "no error")")
        let product = try XCTUnwrap(manager.products.first)

        // Run approval alongside purchase instead of waiting for a particular
        // point where StoreKit returns .pending. The actual deferred transaction
        // tells us that Ask to Buy is awaiting approval.
        var purchaseResult: Bool?
        let purchase = Task { purchaseResult = await manager.purchase(product) }
        defer {
            purchase.cancel()
            for transaction in session.allTransactions() where transaction.state == .deferred {
                try? session.declineAskToBuyTransaction(identifier: transaction.identifier)
            }
        }
        var deferredTransaction: SKTestTransaction?
        let becameDeferred = try await waitUntil(timeout: 10) {
            deferredTransaction = session.allTransactions().first { $0.state == .deferred }
            return deferredTransaction != nil
        }
        XCTAssertTrue(becameDeferred, "Ask to Buy did not create a deferred transaction")
        let pending = try XCTUnwrap(deferredTransaction)
        XCTAssertEqual(manager.tipCount, 0, "A deferred purchase must not grant support")
        XCTAssertFalse(manager.isSupporter)
        XCTAssertTrue(manager.isPending || manager.isPurchasing,
                      "A deferred purchase must remain protected from another tap")
        if let result = purchaseResult {
            XCTAssertFalse(result, "A deferred purchase must not report success before approval")
            XCTAssertTrue(manager.isPending)
            XCTAssertFalse(manager.isPurchasing)
        }
        let duplicatePurchase = await manager.purchase(product)
        XCTAssertFalse(duplicatePurchase, "Repeated taps must not create another deferred purchase")
        XCTAssertEqual(session.allTransactions().count, 1)

        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let completed = try await waitUntil(timeout: 10) {
            purchaseResult != nil && manager.tipCount == 1 && !manager.isPurchasing && !manager.isPending
        }
        XCTAssertTrue(completed, "The approved transaction did not finish and grant support exactly once")
        XCTAssertNotNil(purchaseResult, "purchase() must return after approval")
        XCTAssertEqual(manager.tipCount, 1)
        XCTAssertTrue(manager.isSupporter)
        XCTAssertFalse(manager.isPending)
        XCTAssertFalse(manager.isPurchasing)
        XCTAssertEqual(session.allTransactions().count, 1)
        let restarted = TippingManager(defaults: defaults, startsStoreKit: false)
        XCTAssertEqual(restarted.tipCount, 1, "Approval and purchase-result delivery must persist one tip")
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return condition()
    }
}
#endif
