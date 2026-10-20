#if canImport(StoreKit)
import Foundation
import XCTest
@testable import OnlineNow

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class TippingManagerTests: XCTestCase {
    private func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "OnlineNow.TippingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    func testRestartAndDuplicateUpdateDoNotDoubleCount() throws {
        try withDefaults { defaults in
            let manager = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertTrue(try manager.recordVerifiedTip(id: 1, productID: "onlinenow.gdemay", isRevoked: false))
            let restarted = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertFalse(try restarted.recordVerifiedTip(id: 1, productID: "onlinenow.gdemay", isRevoked: false))
            XCTAssertEqual(restarted.tipCount, 1)
            XCTAssertTrue(restarted.isSupporter)
        }
    }

    func testUnsupportedProductDoesNotGrantSupport() throws {
        try withDefaults { defaults in
            let manager = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertFalse(try manager.recordVerifiedTip(id: 1, productID: "unrelated.product", isRevoked: false))
            XCTAssertEqual(manager.tipCount, 0)
            XCTAssertFalse(manager.isSupporter)
        }
    }

    func testMigratesExistingTipsOnce() throws {
        try withDefaults { defaults in
            defaults.set(3, forKey: "onlinenow.tipCount")
            let manager = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertEqual(manager.tipCount, 3)
            try manager.recordVerifiedTip(id: 1, productID: "onlinenow.gdemay", isRevoked: false)
            let restarted = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertEqual(restarted.tipCount, 4)
        }
    }

    func testRefundPersistsAndRemovesSupporterStatus() throws {
        try withDefaults { defaults in
            let manager = TippingManager(defaults: defaults, startsStoreKit: false)
            try manager.recordVerifiedTip(id: 1, productID: "onlinenow.gdemay", isRevoked: false)
            try manager.recordVerifiedTip(id: 1, productID: "onlinenow.gdemay", isRevoked: true)
            let restarted = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertEqual(restarted.tipCount, 0)
            XCTAssertFalse(restarted.isSupporter)
        }
    }

    func testCorruptLedgerDoesNotSilentlyResetTransactionHistory() throws {
        try withDefaults { defaults in
            defaults.set(Data("invalid json".utf8), forKey: "onlinenow.tipLedger.v1")
            let manager = TippingManager(defaults: defaults, startsStoreKit: false)
            XCTAssertNotNil(manager.errorMessage)
            XCTAssertFalse(try manager.recordVerifiedTip(id: 1, productID: "onlinenow.gdemay", isRevoked: false))
            XCTAssertEqual(manager.tipCount, 0)
        }
    }

    func testFirstSpeedTestAndExportDoNotInterruptWithTipPrompt() {
        withDefaults { defaults in
            let manager = TippingManager(defaults: defaults, startsStoreKit: false)
            manager.recordSpeedTestCompleted()
            manager.recordHistoryExported()
            XCTAssertFalse(manager.shouldShowTipPrompt)
            for _ in 2...10 { manager.recordSpeedTestCompleted() }
            XCTAssertTrue(manager.shouldShowTipPrompt)
            manager.dismissTipPrompt()
            for _ in 1...10 { manager.recordSpeedTestCompleted() }
            XCTAssertFalse(manager.shouldShowTipPrompt)
        }
    }
}
#endif
