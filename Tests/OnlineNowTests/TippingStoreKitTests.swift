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

        // Simulate two actual StoreKit purchases while the app is not listening.
        // This outside-app API does not require the unit host to present payment
        // UI. Purchases from the app, including Ask to Buy, run in the UI suite.
        _ = try await session.buyProduct(identifier: productID)
        _ = try await session.buyProduct(identifier: productID)
        let unfinished = session.allTransactions()
        XCTAssertEqual(unfinished.count, 2)
        XCTAssertEqual(Set(unfinished.map(\.identifier)).count, 2)
        XCTAssertTrue(unfinished.allSatisfy { $0.state == .purchased })
        XCTAssertEqual(beforeRecovery.tipCount, 0)

        let manager = TippingManager(defaults: defaults, startsStoreKit: true)
        let recovered = try await waitUntil(timeout: 10) {
            // Products load only after the unfinished-transaction pass ends.
            manager.tipCount == 2 && !manager.products.isEmpty && !manager.isLoading
        }
        XCTAssertTrue(recovered, "The two unfinished consumables were not recovered")
        XCTAssertEqual(manager.tipCount, 2)
        XCTAssertTrue(manager.isSupporter)
        XCTAssertEqual(manager.products.first?.id, productID)
        XCTAssertEqual(manager.products.first?.type, .consumable)

        // A subsequent outside-app purchase exercises Transaction.updates on
        // the same manager, independently of its startup recovery pass.
        _ = try await session.buyProduct(identifier: productID)
        let updated = try await waitUntil(timeout: 10) { manager.tipCount == 3 }
        XCTAssertTrue(updated, "The new consumable was not delivered through Transaction.updates")
        XCTAssertEqual(manager.tipCount, 3)
        XCTAssertEqual(session.allTransactions().count, 3)
        let restarted = TippingManager(defaults: defaults, startsStoreKit: false)
        XCTAssertEqual(restarted.tipCount, 3, "Recovered and live transactions must persist exactly once")
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
