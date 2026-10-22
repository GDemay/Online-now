import Foundation
import StoreKit
import XCTest
import StoreKitTest

final class OnlineNowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var storeKitSession: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline"]
    }

    override func tearDownWithError() throws {
        // Tear down the app before resetting the process-wide StoreKit service.
        // XCTest still calls this if an assertion stops a test before approval.
        app?.terminate()
        if let store = storeKitSession {
            for transaction in store.allTransactions() where transaction.state == .deferred {
                try? store.declineAskToBuyTransaction(identifier: transaction.identifier)
            }
            store.clearTransactions()
            store.resetToDefaultState()
        }
        storeKitSession = nil
        app = nil
        try super.tearDownWithError()
    }

    func testOfflineRefreshAndHistoryNavigation() throws {
        app.launch()
        let refresh = app.buttons["connectivity.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        app.buttons["navigation.history"].tap()
        XCTAssertTrue(app.otherElements["history.empty"].waitForExistence(timeout: 5)
                      || app.staticTexts["history.empty"].exists)
        attachScreenshot(named: "Online Now - Empty history")
        app.buttons["Done"].tap()
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        refresh.tap()
        XCTAssertTrue(refresh.waitForEnabled(timeout: 10))
        app.buttons["navigation.history"].tap()
        XCTAssertTrue(app.buttons["history.export"].waitForExistence(timeout: 5),
                      "An offline refresh must save a diagnostic history entry")
        XCTAssertFalse(app.otherElements["history.empty"].exists)
        attachScreenshot(named: "Online Now - Offline refresh saved in history")
        app.buttons["Done"].tap()
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
    }

    func testDonationPurchaseAndRepeatedTip() throws {
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        storeKitSession = store
        store.resetToDefaultState()
        store.disableDialogs = true
        store.clearTransactions()
        app.launch()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialTipCount = try recordedTipCount()
        purchase.tap()
        let thanks = app.alerts["Thank you!"]
        XCTAssertTrue(thanks.waitForExistence(timeout: 15))
        thanks.buttons["Done"].tap()
        // The tip jar stays open after gratitude. A second consumable must
        // complete independently and survive closing/reopening the sheet.
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        purchase.tap()
        XCTAssertTrue(thanks.waitForExistence(timeout: 15))
        thanks.buttons["Done"].tap()
        app.buttons["tipJar.close"].tap()
        app.buttons["navigation.tipJar"].tap()
        XCTAssertTrue(purchase.waitForExistence(timeout: 10))
        XCTAssertTrue(purchase.isEnabled)
        XCTAssertEqual(store.allTransactions().count, 2)
        XCTAssertTrue(waitForRecordedTipCount(initialTipCount + 2, timeout: 10))
        attachScreenshot(named: "Online Now - Tip jar after repeat tips", exportForReview: true)
    }

    func testAskToBuyApprovalIsDeliveredOnce() throws {
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        storeKitSession = store
        store.resetToDefaultState()
        store.disableDialogs = true
        store.askToBuyEnabled = true
        store.clearTransactions()
        app.launch()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialTipCount = try recordedTipCount()
        purchase.tap()

        var deferredTransaction: SKTestTransaction?
        XCTAssertTrue(waitUntil(timeout: 15) {
            deferredTransaction = store.allTransactions().first { $0.state == .deferred }
            return deferredTransaction != nil
        }, "The app purchase did not create an actual Ask to Buy transaction")
        let pendingTransaction = try XCTUnwrap(deferredTransaction)
        let pendingMessage = app.staticTexts["tipJar.pending"]
        XCTAssertTrue(pendingMessage.waitForExistence(timeout: 10))
        XCTAssertFalse(purchase.isEnabled, "Pending approval must block another purchase")
        XCTAssertFalse(app.alerts["Thank you!"].exists)
        XCTAssertEqual(try recordedTipCount(), initialTipCount, "Pending purchases must not grant support")
        XCTAssertEqual(store.allTransactions().count, 1, "The disabled action must not create another request")

        try store.approveAskToBuyTransaction(identifier: pendingTransaction.identifier)
        XCTAssertTrue(waitForRecordedTipCount(initialTipCount + 1, timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertFalse(pendingMessage.exists)
        XCTAssertEqual(store.allTransactions().count, 1)

        app.terminate()
        app.launch()
        app.buttons["navigation.tipJar"].tap()
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertTrue(waitForRecordedTipCount(initialTipCount + 1, timeout: 10),
                      "Approval must persist exactly one tip across an app restart")
        XCTAssertFalse(pendingMessage.exists)
        XCTAssertEqual(store.allTransactions().count, 1)
        attachScreenshot(named: "Online Now - Approved Ask to Buy")
    }

    @MainActor
    func testCancelledTipDoesNotShowFailureOrCreditSupport() async throws {
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        storeKitSession = store
        store.resetToDefaultState()
        store.disableDialogs = true
        store.clearTransactions()
        try await store.setSimulatedError(SKTestFailures.Purchase.generic(.userCancelled), forAPI: .purchase)
        app.launch()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialTipCount = try recordedTipCount()
        purchase.tap()
        XCTAssertFalse(app.staticTexts["tipJar.error"].waitForExistence(timeout: 2),
                       "Choosing to cancel a tip must not be presented as a payment failure")
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertEqual(try recordedTipCount(), initialTipCount)
        XCTAssertFalse(app.alerts["Thank you!"].exists)
        try await store.setSimulatedError(nil, forAPI: .purchase)
        attachScreenshot(named: "Online Now - Cancelled tip remains available")
    }

    func testLargeTextNavigation() throws {
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        storeKitSession = store
        store.resetToDefaultState()
        store.disableDialogs = true
        store.clearTransactions()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let history = app.buttons["navigation.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Online Now - Largest text history")
        app.buttons["Done"].tap()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        for _ in 0..<10 where !purchase.isHittable {
            app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable })?.swipeUp()
        }
        XCTAssertTrue(purchase.isHittable, "The tip action must remain reachable at the largest text size")
        XCTAssertLessThanOrEqual(purchase.frame.height, app.frame.height - 150,
                                 "The product title and price must fit together in the visible sheet")
        attachScreenshot(named: "Online Now - Largest text readable tip option")
    }

    private var supportSummary: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "tipJar.support").firstMatch
    }

    private func recordedTipCount() throws -> Int {
        guard supportSummary.exists else { return 0 }
        return try XCTUnwrap(Int(supportSummary.value as? String ?? ""),
                             "The support summary must expose its recorded tip count")
    }

    private func waitForRecordedTipCount(_ count: Int, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            self.supportSummary.exists && Int(self.supportSummary.value as? String ?? "") == count
        }
    }

    private func waitUntil(timeout: TimeInterval, _ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Keep a normal test attachment and optionally export the same unmodified PNG.
    /// The numbered chunks survive Xcode Cloud's downloadable script/test logs,
    /// including when custom-script-created xcresult bundles are not retained.
    private func attachScreenshot(named name: String, exportForReview: Bool = false) {
        let capture = app.screenshot()
        let attachment = XCTAttachment(screenshot: capture)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard exportForReview else { return }
        guard app.launchArguments.contains("--ui-testing"),
              app.launchArguments.contains("--offline") else {
            XCTFail("Review screenshots may only be exported from the isolated offline UI fixture.")
            return
        }

        let png = capture.pngRepresentation
        guard png.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
            XCTFail("The native screenshot did not contain PNG data.")
            return
        }
        let encoded = png.base64EncodedData()
        let chunkSize = 4_000
        let chunkCount = (encoded.count + chunkSize - 1) / chunkSize
        let identifier = UUID().uuidString
        print("ONLINE_NOW_REVIEW_SCREENSHOT_BEGIN id=\(identifier) bytes=\(png.count) chunks=\(chunkCount)")
        for (index, start) in stride(from: 0, to: encoded.count, by: chunkSize).enumerated() {
            let end = min(start + chunkSize, encoded.count)
            let chunk = String(decoding: encoded[start..<end], as: UTF8.self)
            print("ONLINE_NOW_REVIEW_SCREENSHOT_CHUNK id=\(identifier) index=\(index) data=\(chunk)")
        }
        print("ONLINE_NOW_REVIEW_SCREENSHOT_END id=\(identifier)")
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
