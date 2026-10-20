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
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

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
        session.disableDialogs = true
        session.askToBuyEnabled = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let suite = "OnlineNow.AskToBuyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = TippingManager(defaults: defaults, startsStoreKit: true)
        await manager.loadProducts()
        // Automatic startup may already be loading products.
        let deadline = Date().addingTimeInterval(5)
        while manager.products.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let product = try XCTUnwrap(manager.products.first)
        let immediateSuccess = await manager.purchase(product)
        XCTAssertFalse(immediateSuccess)
        XCTAssertTrue(manager.isPending)
        XCTAssertEqual(manager.tipCount, 0)

        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let approvalDeadline = Date().addingTimeInterval(5)
        while manager.tipCount == 0, Date() < approvalDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(manager.tipCount, 1)
        XCTAssertFalse(manager.isPending)
    }
}
#endif
