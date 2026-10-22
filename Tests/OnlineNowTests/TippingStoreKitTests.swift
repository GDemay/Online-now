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

        let manager = TippingManager(defaults: defaults, startsStoreKit: true)
        let recovered = try await waitUntil(timeout: 10) {
            // Products load only after the unfinished-transaction pass ends.
            manager.tipCount == 1 && !manager.products.isEmpty && !manager.isLoading
        }
        XCTAssertTrue(recovered, "The unfinished consumable was not recovered")
        XCTAssertEqual(manager.tipCount, 1)
        XCTAssertTrue(manager.isSupporter)
        XCTAssertEqual(manager.products.first?.id, productID)
        XCTAssertEqual(manager.products.first?.type, .consumable)

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

    private func waitUntil(timeout: TimeInterval, _ condition: () async -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()), Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return await condition()
    }
}
#endif
