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

    func testLargeTextNavigation() throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let history = app.buttons["navigation.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
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

// Appended to OnlineNowUITests.swift only in the isolated native visual-QA branch.
// Deterministic network/history inputs are fixtures; every capture is an original
// screenshot of the actual SwiftUI app. StoreKit flows use SKTestSession.
final class OnlineNowVisualReviewTests: XCTestCase {
    private var app: XCUIApplication!
    private var store: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let store {
            for transaction in store.allTransactions() where transaction.state == .deferred {
                try? store.declineAskToBuyTransaction(identifier: transaction.identifier)
            }
            store.clearTransactions()
            store.resetToDefaultState()
        }
        store = nil
        app = nil
        try super.tearDownWithError()
    }

    func testVisualOfflineAndEmptyStates() throws {
        launch(scenario: "offline")
        require(app.buttons["connectivity.refresh"])
        XCTAssertFalse(app.buttons["connectivity.speedTest"].isEnabled)
        capture("offline-home")
        tap("navigation.history")
        require(emptyHistory)
        capture("history-empty")
        app.buttons["Done"].tap()

        tap("connectivity.speed")
        require(app.buttons["Done"])
        capture("speed-detail-empty-top")
        scrollTo(app.staticTexts["Run Test Speed to start your speed history."])
        capture("speed-detail-empty-history")
        app.buttons["Done"].tap()

        // Manual offline Refresh must now save an explicit failed check.
        tap("connectivity.refresh")
        XCTAssertTrue(app.buttons["connectivity.refresh"].waitForEnabled(timeout: 10))
        tap("navigation.history")
        require(app.buttons["history.export"])
        XCTAssertFalse(emptyHistory.exists)
        capture("history-after-offline-refresh")
    }

    func testVisualOnlineAndManualSpeed() throws {
        launch(scenario: "online", seeded: true)
        waitForReady()
        capture("online-home")
        tap("connectivity.speedTest")
        require(app.buttons["connectivity.speedTest"])
        XCTAssertTrue(waitUntil(5) { !self.app.buttons["connectivity.refresh"].isEnabled })
        capture("speed-test-in-progress")
        XCTAssertTrue(app.buttons["connectivity.refresh"].waitForEnabled(timeout: 12))
        capture("speed-test-completed")
        scrollTo(textContaining("Last Updated"))
        capture("online-network-details")
        scrollTo(app.buttons["connectivity.recentActivity"])
        capture("online-recent-activity")
    }

    func testVisualAllStatDetails() throws {
        launch(scenario: "online", seeded: true)
        waitForReady()
        let stats = [
            ("connectivity.speed", "speed"),
            ("connectivity.latency", "tcp"),
            ("connectivity.quality", "quality"),
            ("connectivity.type", "connection")
        ]
        for (identifier, name) in stats {
            scrollTo(app.buttons[identifier])
            tap(identifier)
            require(app.buttons["Done"])
            capture("detail-\(name)-top")
            let about = identified("statDetail.description")
            require(about)
            scrollTo(about)
            capture("detail-\(name)-about")
            if name == "speed" || name == "tcp" {
                let plot = identified("statDetail.plot")
                require(plot)
                scrollTo(plot)
                capture("detail-\(name)-history-chart")
            }
            let benchmarks = identified("statDetail.benchmarks")
            require(benchmarks)
            scrollTo(benchmarks)
            capture("detail-\(name)-benchmarks")
            let tips = identified("statDetail.tips")
            require(tips)
            scrollTo(tips)
            capture("detail-\(name)-guidance")
            app.buttons["Done"].tap()
        }
    }

    func testVisualHistoryExportAndClear() throws {
        launch(scenario: "online", seeded: true)
        waitForReady()
        tap("navigation.history")
        let export = app.buttons["history.export"]
        require(export)
        capture("history-populated-overview")
        scrollTo(app.staticTexts["Recent Checks"])
        capture("history-populated-records")

        export.tap()
        let save = app.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch
        require(save, timeout: 12)
        XCTAssertTrue(save.waitForEnabled(timeout: 10))
        capture("history-csv-export-picker")
        save.tap()
        let replace = app.buttons.matching(NSPredicate(format: "label == %@", "Replace")).firstMatch
        if replace.waitForExistence(timeout: 1) { replace.tap() }
        XCTAssertTrue(waitUntil(15) { export.exists && export.isHittable && !save.exists },
                      "Saving the exported CSV must return to History")
        XCTAssertFalse(app.alerts["Couldn't Export History"].exists)
        capture("history-csv-saved-return")
        print("ONLINE_NOW_VISUAL_OBSERVATION csv-file-export-save-completed=true")

        // Check cancellation independently; iOS file-browser chrome differs by device.
        export.tap()
        require(save, timeout: 10)
        let cancel = app.buttons.matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
        } else {
            let screen = app.frame
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: screen.midX, dy: screen.minY + screen.height * 0.09))
            let end = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: screen.midX, dy: screen.minY + screen.height * 0.75))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        let cancelled = waitUntil(8) { export.exists && export.isHittable && !save.exists }
        print("ONLINE_NOW_VISUAL_OBSERVATION csv-file-export-cancel-completed=\(cancelled)")
        if cancelled {
            XCTAssertFalse(app.alerts["Couldn't Export History"].exists)
            capture("history-csv-cancelled-return")
        } else {
            capture("history-csv-cancellation-ui-unavailable")
            app.terminate()
            launch(scenario: "online", seeded: true)
            waitForReady()
            tap("navigation.history")
        }
        require(app.buttons["history.clear"])
        app.buttons["history.clear"].tap()
        let clear = app.buttons["Clear All"]
        require(clear)
        capture("history-clear-confirmation")
        let dismiss = app.buttons["Cancel"]
        if dismiss.exists && dismiss.isHittable {
            dismiss.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.25)).tap()
        }
        require(app.buttons["history.export"])
        capture("history-clear-cancel-preserved")
        app.buttons["history.clear"].tap()
        require(app.buttons["Clear All"])
        app.buttons["Clear All"].tap()
        require(emptyHistory)
        XCTAssertFalse(app.buttons["history.export"].exists)
        capture("history-cleared")
    }

    func testVisualLimitedCheckingAndSpeedFailure() throws {
        launch(scenario: "limited")
        waitForReady()
        capture("limited-connectivity-home")
        scrollTo(textContaining("Connection Quality"))
        capture("limited-connectivity-details")
        app.terminate()

        launch(scenario: "checking")
        require(app.buttons["connectivity.refresh"])
        capture("connection-check-in-progress")
        app.terminate()

        launch(scenario: "speed-error")
        waitForReady()
        tap("connectivity.speedTest")
        XCTAssertTrue(app.buttons["connectivity.refresh"].waitForEnabled(timeout: 12))
        require(app.descendants(matching: .any).matching(identifier: "measurementError").firstMatch)
        capture("speed-test-failure")
        XCTAssertTrue(app.buttons["connectivity.speedTest"].isEnabled)
    }

    func testVisualTipPurchaseAndRepeat() throws {
        let session = try configureStore()
        launch(scenario: "offline")
        tap("navigation.tipJar")
        let purchase = app.buttons["tipJar.purchase"]
        require(purchase, timeout: 15)
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        capture("tip-jar-product")
        let initialCount = recordedTipCount()
        scrollTo(purchase)
        purchase.tap()
        let thanks = app.alerts["Thank you!"]
        require(thanks, timeout: 15)
        capture("tip-purchase-thank-you")
        thanks.buttons["Done"].tap()
        scrollTo(supportSummary)
        XCTAssertTrue(waitUntil(10) { self.recordedTipCount() == initialCount + 1 })
        capture("tip-jar-recorded-support")
        scrollTo(purchase)
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        purchase.tap()
        require(thanks, timeout: 15)
        thanks.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(10) { self.recordedTipCount() == initialCount + 2 })
        XCTAssertEqual(session.allTransactions().count, 2)
        scrollTo(supportSummary)
        capture("tip-jar-repeat-purchase")
    }

    func testVisualAskToBuyPendingAndApproval() throws {
        let session = try configureStore()
        session.askToBuyEnabled = true
        launch(scenario: "offline")
        tap("navigation.tipJar")
        let purchase = app.buttons["tipJar.purchase"]
        require(purchase, timeout: 15)
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialCount = recordedTipCount()
        scrollTo(purchase)
        purchase.tap()
        XCTAssertTrue(waitUntil(15) { session.allTransactions().contains { $0.state == .deferred } })
        let deferred = try XCTUnwrap(session.allTransactions().first { $0.state == .deferred })
        let pending = app.staticTexts["tipJar.pending"]
        require(pending, timeout: 10)
        XCTAssertFalse(purchase.isEnabled)
        XCTAssertEqual(recordedTipCount(), initialCount)
        scrollTo(pending)
        capture("tip-awaiting-parental-approval")
        try session.approveAskToBuyTransaction(identifier: deferred.identifier)
        XCTAssertTrue(waitUntil(15) { self.recordedTipCount() == initialCount + 1 })
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertFalse(pending.exists)
        scrollTo(supportSummary)
        capture("tip-approved-once")
    }

    @MainActor
    func testVisualTipFailureAndRecovery() async throws {
        let session = try configureStore()
        let simulatedFailure = SKTestFailures.Purchase.generic(.unknown)
        try await session.setSimulatedError(simulatedFailure, forAPI: .purchase)
        let configuredFailure = await session.simulatedError(forAPI: .purchase)
        XCTAssertEqual(configuredFailure, simulatedFailure)
        launch(scenario: "offline")
        tap("navigation.tipJar")
        let purchase = app.buttons["tipJar.purchase"]
        require(purchase, timeout: 15)
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialCount = recordedTipCount()
        scrollTo(purchase)
        purchase.tap()
        let error = app.staticTexts["tipJar.error"]
        require(error, timeout: 15)
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertEqual(recordedTipCount(), initialCount)
        scrollTo(error)
        capture("tip-purchase-failed-retry")
        print("ONLINE_NOW_STOREKIT_ERROR_CONTEXT phase=purchase-failure json=\(error.value as? String ?? "")")
        try await session.setSimulatedError(nil, forAPI: .purchase)
        let clearedFailure = await session.simulatedError(forAPI: .purchase)
        XCTAssertNil(clearedFailure)
        scrollTo(purchase)
        purchase.tap()
        let thanks = app.alerts["Thank you!"]
        require(thanks, timeout: 15)
        thanks.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(10) { self.recordedTipCount() == initialCount + 1 })
        scrollTo(supportSummary)
        capture("tip-purchase-recovered")
    }

    @MainActor
    func testVisualTipCancellation() async throws {
        let session = try configureStore()
        let cancellation = SKTestFailures.Purchase.generic(.userCancelled)
        try await session.setSimulatedError(cancellation, forAPI: .purchase)
        let configuredCancellation = await session.simulatedError(forAPI: .purchase)
        XCTAssertEqual(configuredCancellation, cancellation)
        launch(scenario: "offline")
        tap("navigation.tipJar")
        let simulatedPurchase = app.buttons["tipJar.purchase"]
        require(simulatedPurchase, timeout: 15)
        XCTAssertTrue(simulatedPurchase.waitForEnabled(timeout: 10))
        let preCancellationCount = recordedTipCount()
        scrollTo(simulatedPurchase)
        simulatedPurchase.tap()
        XCTAssertTrue(simulatedPurchase.waitForEnabled(timeout: 10))
        XCTAssertEqual(recordedTipCount(), preCancellationCount)
        XCTAssertFalse(app.alerts["Thank you!"].exists)
        capture("tip-cancelled-storekit-response")
        print("ONLINE_NOW_VISUAL_OBSERVATION storekit-user-cancellation-injected=true purchase-enabled=\(simulatedPurchase.isEnabled) credited=false error-message-visible=\(app.staticTexts["tipJar.error"].exists)")
        let cancellationError = app.staticTexts["tipJar.error"]
        if cancellationError.exists {
            print("ONLINE_NOW_STOREKIT_ERROR_CONTEXT phase=user-cancellation json=\(cancellationError.value as? String ?? "")")
        }
        try await session.setSimulatedError(nil, forAPI: .purchase)
        let clearedCancellation = await session.simulatedError(forAPI: .purchase)
        XCTAssertNil(clearedCancellation)
        app.terminate()

        // Separately observe real checkout dismissal when this simulator presents it.
        session.disableDialogs = false
        launch(scenario: "offline")
        tap("navigation.tipJar")
        let purchase = app.buttons["tipJar.purchase"]
        require(purchase, timeout: 15)
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialCount = recordedTipCount()
        scrollTo(purchase)
        purchase.tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        let systemCancel = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .buttons.matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        if cancel.waitForExistence(timeout: 8) {
            capture("tip-payment-confirmation")
            cancel.tap()
        } else if systemCancel.exists {
            capture("tip-payment-system-confirmation")
            systemCancel.tap()
        } else {
            // Record an environment limitation rather than claiming a cancellation.
            capture("tip-payment-cancellation-ui-unavailable")
            print("ONLINE_NOW_VISUAL_OBSERVATION payment-cancellation-ui-available=false")
            return
        }
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertEqual(recordedTipCount(), initialCount)
        XCTAssertFalse(app.alerts["Thank you!"].exists)
        capture("tip-payment-cancelled")
        print("ONLINE_NOW_VISUAL_OBSERVATION payment-cancellation-ui-available=true")
    }

    func testVisualDarkMode() throws {
        _ = try configureStore()
        launch(scenario: "online", seeded: true, flags: ["--dark-mode"])
        waitForReady()
        capture("dark-home")
        tap("navigation.history")
        require(app.buttons["history.export"])
        capture("dark-history")
        app.buttons["Done"].tap()
        tap("navigation.tipJar")
        require(app.buttons["tipJar.purchase"], timeout: 15)
        capture("dark-tip-jar")
    }

    func testVisualAccessibilityLargestText() throws {
        _ = try configureStore()
        launch(scenario: "online", seeded: true, flags: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        waitForReady()
        XCTAssertTrue(app.buttons["navigation.history"].isHittable)
        capture("ax5-home-top")
        scrollTo(app.buttons["connectivity.speedTest"])
        capture("ax5-measurement-controls")
        scrollTo(textContaining("Network Details"), maximumSwipes: 20)
        capture("ax5-network-details-top")
        scrollTo(textContaining("Connection Quality"), maximumSwipes: 20)
        capture("ax5-network-details-quality")
        scrollTo(app.buttons["connectivity.recentActivity"], maximumSwipes: 20)
        capture("ax5-recent-activity")
        scrollTo(app.buttons["connectivity.speed"], maximumSwipes: 28, towardsTopWhenMissing: true)
        tap("connectivity.speed")
        require(app.buttons["Done"])
        capture("ax5-speed-detail-top")
        scrollTo(app.staticTexts["Benchmarks"], maximumSwipes: 16)
        capture("ax5-speed-detail-benchmarks")
        app.buttons["Done"].tap()
        tap("navigation.history")
        require(app.buttons["history.export"])
        capture("ax5-history-overview")
        scrollTo(app.staticTexts["Recent Checks"], maximumSwipes: 16)
        capture("ax5-history-records")
        app.buttons["Done"].tap()
        tap("navigation.tipJar")
        require(app.buttons["tipJar.purchase"], timeout: 15)
        capture("ax5-tip-jar-top")
        scrollTo(app.buttons["tipJar.purchase"], maximumSwipes: 16)
        capture("ax5-tip-jar-purchase")
        print("ONLINE_NOW_VISUAL_OBSERVATION ax5-purchase-hittable=\(app.buttons["tipJar.purchase"].isHittable)")
    }

    func testVisualAccessibilityTipPrompt() throws {
        _ = try configureStore()
        let flags = ["--tip-prompt", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(scenario: "offline", flags: flags)
        require(app.buttons["tipPrompt.dismiss"])
        capture("ax5-optional-tip-prompt")
        scrollTo(app.buttons["tipPrompt.dismiss"], maximumSwipes: 16)
        capture("ax5-tip-prompt-dismiss-action")
        XCTAssertTrue(app.buttons["tipPrompt.dismiss"].isHittable)
        app.buttons["tipPrompt.dismiss"].tap()
        require(app.buttons["navigation.history"])
        app.terminate()

        launch(scenario: "offline", flags: flags)
        scrollTo(app.buttons["tipPrompt.open"], maximumSwipes: 16)
        capture("ax5-tip-prompt-open-action")
        XCTAssertTrue(app.buttons["tipPrompt.open"].isHittable)
        app.buttons["tipPrompt.open"].tap()
        require(app.buttons["tipJar.close"])
        capture("ax5-tip-prompt-opened-tip-jar")
    }

    func testVisualMeteredAndPossibleVPN() throws {
        launch(scenario: "online", flags: ["--possible-vpn", "--low-data-mode", "--metered"])
        waitForReady()
        capture("possible-vpn-home")
        scrollTo(textContaining("VPN Detection"))
        capture("low-data-mode-and-vpn-details")
    }

    func testVisualLiveNetworkSmoke() throws {
        app.launchArguments = ["--ui-testing", "--visual-review", "--live-network"]
        app.launch()
        require(app.buttons["navigation.history"])
        capture("live-network-initial-state")
        // External reachability is observational, not a deterministic test gate.
        let completed = app.buttons["connectivity.refresh"].waitForEnabled(timeout: 25)
        print("ONLINE_NOW_VISUAL_OBSERVATION live-network-check-completed=\(completed)")
        capture("live-network-observed-home")
        scrollTo(textContaining("Connection Quality"))
        capture("live-network-observed-details")
        tap("navigation.history")
        require(app.buttons["Done"])
        capture("live-network-observed-history")
    }

    func testVisualExceptionalAndPromptStates() throws {
        launch(scenario: "offline", flags: ["--tip-prompt"])
        require(app.buttons["tipPrompt.dismiss"])
        capture("optional-tip-prompt")
        app.buttons["tipPrompt.dismiss"].tap()
        XCTAssertFalse(app.buttons["tipPrompt.dismiss"].exists)
        app.terminate()

        launch(scenario: "offline", flags: ["--tip-unavailable"])
        tap("navigation.tipJar")
        require(app.staticTexts["tipJar.unavailable"])
        capture("tip-catalog-unavailable")
        XCTAssertTrue(app.buttons["tipJar.retry"].exists)
        app.terminate()

        launch(scenario: "offline", flags: ["--tip-loading"])
        tap("navigation.tipJar")
        require(app.descendants(matching: .any).matching(identifier: "tipJar.loading").firstMatch)
        capture("tip-catalog-loading")
        app.terminate()

        launch(scenario: "offline", flags: ["--temporary-history"])
        require(textContaining("History is temporarily unavailable"))
        capture("temporary-history-storage-notice")
        app.terminate()

        launch(scenario: "offline", flags: ["--history-open-failure"])
        require(app.buttons["Try Again"])
        capture("history-storage-open-failure")
    }

    private func launch(scenario: String, seeded: Bool = false, flags: [String] = []) {
        app.launchArguments = ["--ui-testing", "--visual-review"]
        app.launchArguments.append(scenario == "offline" ? "--offline" : "--scenario-\(scenario)")
        if seeded { app.launchArguments.append("--seed-history") }
        app.launchArguments += flags
        app.launch()
    }

    private func configureStore() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        store = session
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func waitForReady() {
        require(app.buttons["connectivity.refresh"])
        XCTAssertTrue(app.buttons["connectivity.refresh"].waitForEnabled(timeout: 10))
    }

    private var emptyHistory: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "history.empty").firstMatch
    }

    private var supportSummary: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "tipJar.support").firstMatch
    }

    private func recordedTipCount() -> Int {
        // The support summary is intentionally absent before the first tip.
        guard supportSummary.exists else { return 0 }
        return Int(supportSummary.value as? String ?? "") ?? 0
    }

    private func textContaining(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func require(_ element: XCUIElement, timeout: TimeInterval = 8,
                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected UI element: \(element)", file: file, line: line)
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[identifier]
        require(button, file: file, line: line)
        if !button.isHittable { scrollTo(button) }
        XCTAssertTrue(button.isHittable, "Control must be usable: \(identifier)", file: file, line: line)
        button.tap()
    }

    private func identified(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The last visible scroll view belongs to the current sheet, rather than
    /// the still-present Home scroll view underneath a modal on iPad.
    private var activeScrollView: XCUIElement? {
        app.scrollViews.allElementsBoundByIndex.last {
            $0.exists && $0.isHittable && !$0.frame.intersection(app.frame).isEmpty
        }
    }

    private func visibleViewport(for scroll: XCUIElement?) -> CGRect {
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        for bar in app.navigationBars.allElementsBoundByIndex where bar.exists && bar.isHittable {
            let rect = bar.frame
            if rect.intersects(viewport), rect.maxY < viewport.maxY,
               rect.width > viewport.width * 0.5 {
                let top = max(viewport.minY, rect.maxY)
                viewport = CGRect(x: viewport.minX, y: top, width: viewport.width,
                                  height: max(1, viewport.maxY - top))
            }
        }
        if viewport.isNull || viewport.width < 40 || viewport.height < 40 { viewport = app.frame }
        return viewport.insetBy(dx: 6, dy: 10)
    }

    private func scrollTo(_ element: XCUIElement, maximumSwipes: Int = 16,
                          towardsTopWhenMissing: Bool = false) {
        for _ in 0..<maximumSwipes {
            let scroll = activeScrollView
            let viewport = visibleViewport(for: scroll)
            let exists = element.exists
            let frame = exists ? element.frame : .zero
            if exists, !frame.isEmpty {
                if frame.height <= viewport.height,
                   viewport.contains(CGPoint(x: frame.midX, y: frame.minY)),
                   viewport.contains(CGPoint(x: frame.midX, y: frame.maxY)) {
                    return
                }
                if frame.height > viewport.height,
                   frame.minY >= viewport.minY - 8, frame.minY <= viewport.minY + 35 {
                    return
                }
            }
            let delta: CGFloat
            if exists, !frame.isEmpty {
                delta = frame.height > viewport.height
                    ? frame.minY - viewport.minY : frame.midY - viewport.midY
            } else {
                delta = viewport.height * (towardsTopWhenMissing ? -0.25 : 0.25)
            }
            let step = min(viewport.height * 0.25, max(28, abs(delta)))
            let x = viewport.minX + viewport.width * 0.88
            let midY = viewport.midY
            let upwards = delta >= 0
            let startY = midY + (upwards ? step / 2 : -step / 2)
            let endY = midY - (upwards ? step / 2 : -step / 2)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: startY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: endY - app.frame.minY))
            start.press(forDuration: 0.03, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    private func swipeUpOnce() {
        if let scroll = activeScrollView { scroll.swipeUp(velocity: .slow) }
        else { app.swipeUp(velocity: .slow) }
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func capture(_ name: String) {
        guard app.launchArguments.contains("--ui-testing"),
              app.launchArguments.contains("--visual-review") else {
            XCTFail("Visual captures must come from the isolated UI-test process")
            return
        }
        // Settle short SwiftUI transitions without blocking the app process.
        Thread.sleep(forTimeInterval: 0.5)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Online Now - Visual review - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let png = screenshot.pngRepresentation
        guard png.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
            XCTFail("The native capture is not PNG data")
            return
        }
        func slug(_ value: String) -> String {
            value.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined()
        }
        let environment = ProcessInfo.processInfo.environment
        let model = slug(environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown")
        let device = slug(environment["SIMULATOR_DEVICE_NAME"] ?? model)
        let encoded = png.base64EncodedData()
        let chunkSize = 4_000
        let count = (encoded.count + chunkSize - 1) / chunkSize
        let id = UUID().uuidString
        print("ONLINE_NOW_MARKETING_SCREENSHOT_BEGIN id=\(id) name=\(name) device=\(device) bytes=\(png.count) chunks=\(count) model=\(model)")
        for (index, start) in stride(from: 0, to: encoded.count, by: chunkSize).enumerated() {
            let end = min(start + chunkSize, encoded.count)
            let chunk = String(decoding: encoded[start..<end], as: UTF8.self)
            print("ONLINE_NOW_MARKETING_SCREENSHOT_CHUNK id=\(id) index=\(index) data=\(chunk)")
        }
        print("ONLINE_NOW_MARKETING_SCREENSHOT_END id=\(id)")
    }
}
