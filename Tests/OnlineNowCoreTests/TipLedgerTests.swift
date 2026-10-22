import Foundation
import XCTest
#if canImport(OnlineNowCore)
@testable import OnlineNowCore
#else
@testable import OnlineNow
#endif

final class TipLedgerTests: XCTestCase {
    func testPurchaseAndUpdateDeliveryAreCountedExactlyOnce() {
        var ledger = TipLedger()
        XCTAssertTrue(ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: false))
        XCTAssertFalse(ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: false))
        XCTAssertEqual(ledger.tipCount, 1)
        XCTAssertEqual(ledger.entries.count, 1)
    }

    func testRepeatConsumablePurchasesCountAsSeparateTips() {
        var ledger = TipLedger()
        ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: false)
        ledger.record(id: 11, productID: "onlinenow.gdemay", isRevoked: false)
        XCTAssertEqual(ledger.tipCount, 2)
    }

    func testRefundRemovesTipAndOldDeliveryCannotRestoreIt() {
        var ledger = TipLedger()
        ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: false)
        XCTAssertTrue(ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: true))
        XCTAssertEqual(ledger.tipCount, 0)
        XCTAssertFalse(ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: false))
        XCTAssertFalse(ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: true))
        XCTAssertEqual(ledger.tipCount, 0)
    }

    func testRefundReceivedBeforePurchaseNeverGrantsSupport() {
        var ledger = TipLedger()
        ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: true)
        ledger.record(id: 10, productID: "onlinenow.gdemay", isRevoked: false)
        XCTAssertEqual(ledger.tipCount, 0)
    }

    func testPersistencePreservesDeduplicationAndLegacyCount() throws {
        var ledger = TipLedger(legacyTipCount: 4)
        ledger.record(id: UInt64.max, productID: "onlinenow.gdemay", isRevoked: false)
        let data = try JSONEncoder().encode(ledger)
        var restored = try JSONDecoder().decode(TipLedger.self, from: data)
        XCTAssertEqual(restored, ledger)
        XCTAssertFalse(restored.record(id: UInt64.max, productID: "onlinenow.gdemay", isRevoked: false))
        XCTAssertEqual(restored.tipCount, 5)
    }
}
