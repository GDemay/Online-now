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
            XCTAssertTrue(manager.purchasesEnabled)
            XCTAssertTrue(manager.tipPromptsEnabled,
                          "The SDK default must preserve its existing prompt behavior")
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

    func testManualTipsStayEnabledWithoutAutomaticPromptsOrCooldown() {
        withDefaults { defaults in
            let manager = TippingManager(
                defaults: defaults, startsStoreKit: false,
                purchasesEnabled: true, tipPromptsEnabled: false)
            XCTAssertTrue(manager.purchasesEnabled,
                          "Disabling prompts must leave user-initiated tips available")
            XCTAssertFalse(manager.tipPromptsEnabled)

            for _ in 1...2 {
                for _ in 1...10 {
                    manager.recordSpeedTestCompleted()
                    manager.recordHistoryExported()
                }
                XCTAssertFalse(manager.shouldShowTipPrompt)
                XCTAssertNil(manager.tipPromptTrigger)
                XCTAssertNil(defaults.object(forKey: "onlinenow.lastTipPrompt"),
                             "Manual-only tipping must not consume a future prompt cooldown")
            }

            // A client opting back into the SDK default must retain its prompt
            // behavior; the manual-only manager must not silently defer it.
            let defaultManager = TippingManager(defaults: defaults, startsStoreKit: false)
            for _ in 1...10 { defaultManager.recordSpeedTestCompleted() }
            XCTAssertTrue(defaultManager.shouldShowTipPrompt)
            XCTAssertNotNil(defaultManager.tipPromptTrigger)
            XCTAssertNotNil(defaults.object(forKey: "onlinenow.lastTipPrompt"))
        }
    }

    func testDisabledPurchasesNeverPromptAfterFrequentUse() {
        withDefaults { defaults in
            let manager = TippingManager(
                defaults: defaults, startsStoreKit: false, purchasesEnabled: false)
            XCTAssertFalse(manager.purchasesEnabled)
            for _ in 1...100 {
                manager.recordSpeedTestCompleted()
                manager.recordHistoryExported()
            }
            XCTAssertFalse(manager.shouldShowTipPrompt)
            XCTAssertNil(manager.tipPromptTrigger)
            XCTAssertNil(defaults.object(forKey: "onlinenow.lastTipPrompt"),
                         "Deferring purchases must not consume a future prompt cooldown")
        }
    }

    func testDisabledPurchasesKeepLegacyAndVerifiedSupportBookkeeping() throws {
        try withDefaults { defaults in
            defaults.set(3, forKey: "onlinenow.tipCount")
            let manager = TippingManager(
                defaults: defaults, startsStoreKit: false, purchasesEnabled: false)
            XCTAssertEqual(manager.tipCount, 3)
            XCTAssertTrue(manager.isSupporter)
            XCTAssertTrue(try manager.recordVerifiedTip(
                id: 91, productID: "onlinenow.gdemay", isRevoked: false))
            XCTAssertFalse(try manager.recordVerifiedTip(
                id: 91, productID: "onlinenow.gdemay", isRevoked: false))

            let restarted = TippingManager(
                defaults: defaults, startsStoreKit: false, purchasesEnabled: false)
            XCTAssertEqual(restarted.tipCount, 4,
                           "Deferring new purchases must preserve existing recorded support")
            XCTAssertTrue(try restarted.recordVerifiedTip(
                id: 91, productID: "onlinenow.gdemay", isRevoked: true))
            XCTAssertEqual(restarted.tipCount, 3,
                           "Verified refunds must still update existing bookkeeping")
        }
    }
}
#endif
