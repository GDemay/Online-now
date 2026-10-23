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
        attachScreenshot(named: "Online Now - Local tipping fixture - Tip jar after repeat tips", exportForReview: true)
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
        attachScreenshot(named: "Online Now - Local tipping fixture - Approved Ask to Buy")
    }

    @MainActor
    func testCancelledTipDoesNotShowFailureOrCreditSupport() async throws {
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        storeKitSession = store
        store.resetToDefaultState()
        store.disableDialogs = false
        store.clearTransactions()
        app.launch()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        let initialTipCount = try recordedTipCount()
        purchase.tap()

        // Dismiss the actual StoreKit confirmation. Injecting .userCancelled
        // does not reliably preserve the typed error in the simulator service.
        XCTAssertTrue(waitUntil(timeout: 15) {
            self.storeKitCheckoutHeading() != nil || self.storeKitDismissButton() != nil
        }, "The native StoreKit checkout must be visible before testing cancellation")
        attachScreenshot(named: "Online Now - Local tipping fixture - Native checkout before cancellation", exportForReview: true)
        if let close = storeKitDismissButton() {
            close.tap()
        } else {
            // Original native phone/iPad captures place X in the leading edge
            // of the centered checkout header. Use its observed Xcode heading
            // as the anchor; never tap a guessed location without that heading.
            let heading = try XCTUnwrap(storeKitCheckoutHeading(), "A checkout heading is required for the coordinate fallback")
            let screen = app.frame
            let sheetWidth = min(screen.width - 16, 440)
            let point = CGPoint(x: screen.midX - sheetWidth / 2 + 32, y: heading.frame.midY)
            XCTAssertTrue(screen.contains(point))
            XCTAssertLessThan(point.x, heading.frame.minX)
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: point.x - screen.minX, dy: point.y - screen.minY)).tap()
        }

        XCTAssertTrue(waitUntil(timeout: 15) {
            self.storeKitCheckoutHeading() == nil && purchase.exists && purchase.isHittable && purchase.isEnabled
        }, "Cancelling checkout must dismiss StoreKit and return to the enabled tip action")
        XCTAssertFalse(app.staticTexts["tipJar.error"].waitForExistence(timeout: 2),
                       "Choosing to cancel a tip must not be presented as a payment failure")
        XCTAssertEqual(try recordedTipCount(), initialTipCount)
        XCTAssertFalse(app.alerts["Thank you!"].exists)
        XCTAssertFalse(store.allTransactions().contains { $0.state == .purchased || $0.state == .deferred },
                       "Cancellation must not create a purchased or deferred tip")
        attachScreenshot(named: "Online Now - Local tipping fixture - Native cancelled tip remains available", exportForReview: true)
    }

    /// Query existing hosts only: activating a system service would alter the flow.
    private func runningCheckoutHosts() -> [XCUIApplication] {
        [XCUIApplication(bundleIdentifier: "com.apple.ios.StoreKitUIService"),
         XCUIApplication(bundleIdentifier: "com.apple.springboard"), app].filter {
            $0.state == .runningForeground || $0.state == .runningBackground
        }
    }

    private func storeKitCheckoutHeading() -> XCUIElement? {
        for host in runningCheckoutHosts() {
            let headings = host.staticTexts.matching(NSPredicate(format: "label == %@", "Xcode"))
            for heading in headings.allElementsBoundByIndex where heading.exists && heading.isHittable {
                if !heading.frame.isEmpty && heading.frame.intersects(app.frame) { return heading }
            }
        }
        return nil
    }

    private func storeKitDismissButton() -> XCUIElement? {
        let labels = Set(["close", "cancel", "dismiss", "x", "×", "cancel purchase"])
        for host in runningCheckoutHosts() {
            for button in host.buttons.allElementsBoundByIndex.reversed() {
                guard button.identifier != "tipJar.close", button.exists, button.isHittable else { continue }
                let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let identifier = button.identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if labels.contains(label) || labels.contains(identifier) { return button }
            }
        }
        return nil
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
        attachScreenshot(named: "Online Now - Local tipping fixture - Largest text history")
        app.buttons["Done"].tap()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        try scrollTipCardIntoViewport(purchase)
        XCTAssertTrue(purchase.isHittable, "The tip action must remain reachable at the largest text size")
        XCTAssertLessThanOrEqual(purchase.frame.height, app.frame.height - 150,
                                 "The product title and price must fit together in the visible sheet")
        attachScreenshot(named: "Online Now - Local StoreKit - Largest text readable tip option", exportForReview: true)
    }

    func testDefaultOptionalTipsKeepCoreNavigationAvailable() throws {
        // The app's default tipping policy matches Release. Only the catalog
        // and isolated offline/history data are local test fixtures.
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        storeKitSession = store
        store.resetToDefaultState()
        store.disableDialogs = true
        store.clearTransactions()
        app.launch()

        let refresh = app.buttons["connectivity.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        let tipJar = app.buttons["navigation.tipJar"]
        XCTAssertTrue(tipJar.waitForExistence(timeout: 5))
        XCTAssertTrue(tipJar.isHittable)
        XCTAssertEqual(tipJar.label, "Support developer")
        XCTAssertFalse(app.buttons["tipPrompt.open"].exists)
        attachScreenshot(named: "Online Now - Default optional tips - Offline Home", exportForReview: true)

        tipJar.tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
        XCTAssertTrue(purchase.isHittable)
        XCTAssertTrue(purchase.label.hasPrefix("Send a one-time tip of "))
        XCTAssertTrue(app.staticTexts["An optional tip helps keep the app maintained. Every feature stays free, whether you tip or not."].exists)
        XCTAssertTrue(store.allTransactions().isEmpty,
                      "Opening the optional tip jar must not start a purchase")
        attachScreenshot(named: "Online Now - Local StoreKit - Default optional tip jar", exportForReview: true)
        let close = app.buttons["tipJar.close"]
        XCTAssertTrue(close.isHittable)
        close.tap()

        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        XCTAssertTrue(refresh.waitForEnabled(timeout: 10))
        refresh.tap()
        XCTAssertTrue(refresh.waitForEnabled(timeout: 10))
        let history = app.buttons["navigation.history"]
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.buttons["history.export"].waitForExistence(timeout: 5),
                      "Declining to send a tip must keep saved history and CSV export available")
        XCTAssertFalse(app.buttons["tipPrompt.open"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(tipJar.waitForExistence(timeout: 5))
        XCTAssertTrue(tipJar.isHittable)
        XCTAssertTrue(store.allTransactions().isEmpty)
        XCTAssertFalse(app.buttons["tipPrompt.open"].exists)
    }

    func testDisabledPurchaseSDKFixtureKeepsCoreNavigation() throws {
        // Exercise the retained public SDK opt-out, rather than the shipping
        // app's default optional-tip policy.
        app.launchArguments.append("--purchases-disabled-ui-fixture")
        app.launch()
        let refresh = app.buttons["connectivity.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        assertNoPurchaseEntryPoints()
        attachScreenshot(named: "Online Now - SDK purchases-disabled fixture - Offline Home", exportForReview: true)

        refresh.tap()
        XCTAssertTrue(refresh.waitForEnabled(timeout: 10))
        let history = app.buttons["navigation.history"]
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.buttons["history.export"].waitForExistence(timeout: 5),
                      "The purchases-disabled SDK must retain saved history and CSV export")
        assertNoPurchaseEntryPoints()
        attachScreenshot(named: "Online Now - SDK purchases-disabled fixture - Saved offline history", exportForReview: true)
        app.buttons["Done"].tap()
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        assertNoPurchaseEntryPoints()

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        XCTAssertTrue(history.isHittable, "History must remain reachable at the largest text size")
        assertNoPurchaseEntryPoints()
        attachScreenshot(named: "Online Now - SDK purchases-disabled fixture - Largest text Home", exportForReview: true)
        history.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        assertNoPurchaseEntryPoints()
        try expandHistoryForEmptyStateCapture()
        attachScreenshot(named: "Online Now - SDK purchases-disabled fixture - Largest text empty history", exportForReview: true)
        done.tap()
        XCTAssertTrue(history.waitForExistence(timeout: 5))
    }

    private func assertNoPurchaseEntryPoints(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.buttons["navigation.tipJar"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["tipJar.purchase"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["tipPrompt.open"].exists, file: file, line: line)
    }

    /// Use the front sheet's scroll view, rather than Home behind an iPad modal.
    private var activeScrollView: XCUIElement? {
        app.scrollViews.allElementsBoundByIndex.last {
            $0.exists && !$0.frame.intersection(app.frame).isEmpty
        }
    }

    private func visibleViewport(for scroll: XCUIElement) -> CGRect {
        var viewport = scroll.frame.intersection(app.frame)
        for bar in app.navigationBars.allElementsBoundByIndex where bar.exists {
            let frame = bar.frame
            if frame.intersects(viewport), frame.width > viewport.width * 0.5,
               frame.maxY < viewport.maxY {
                let top = max(viewport.minY, frame.maxY)
                viewport = CGRect(x: viewport.minX, y: top, width: viewport.width,
                                  height: viewport.maxY - top)
            }
        }
        return viewport.insetBy(dx: 0, dy: 10)
    }

    private func verticallyContains(_ frame: CGRect, in viewport: CGRect) -> Bool {
        !frame.isEmpty && !viewport.isEmpty
            && frame.minY >= viewport.minY && frame.maxY <= viewport.maxY
    }

    private func dragFromObservedFrame(from start: CGPoint, to end: CGPoint) {
        let screen = app.frame
        XCTAssertTrue(screen.contains(start) && screen.contains(end))
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: start.x - screen.minX, dy: start.y - screen.minY))
            .press(forDuration: 0.03, thenDragTo: origin.withOffset(CGVector(
                dx: end.x - screen.minX, dy: end.y - screen.minY)),
                   withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func scrollTipCardIntoViewport(_ card: XCUIElement) throws {
        for _ in 0..<12 {
            let scroll = try XCTUnwrap(activeScrollView)
            let viewport = visibleViewport(for: scroll)
            let frame = card.frame
            XCTAssertLessThanOrEqual(frame.height, viewport.height,
                                     "The complete tip card must fit in the visible sheet")
            if card.isHittable, verticallyContains(frame, in: viewport) { break }
            let delta = frame.midY - viewport.midY
            let step = min(viewport.height * 0.25, max(28, abs(delta)))
            let direction: CGFloat = delta >= 0 ? 1 : -1
            let x = viewport.minX + viewport.width * 0.88
            dragFromObservedFrame(
                from: CGPoint(x: x, y: viewport.midY + direction * step / 2),
                to: CGPoint(x: x, y: viewport.midY - direction * step / 2))
        }
        let viewport = visibleViewport(for: try XCTUnwrap(activeScrollView))
        XCTAssertTrue(card.isHittable && verticallyContains(card.frame, in: viewport),
                      "The entire tip card must be inside the visible scroll viewport before capture")
    }

    private func expandHistoryForEmptyStateCapture() throws {
        let screen = app.frame
        let frontBar = {
            self.app.navigationBars.allElementsBoundByIndex.last {
                $0.exists && $0.buttons["Done"].exists
            }
        }
        let initial = try XCTUnwrap(frontBar()).frame
        for _ in 0..<2 {
            let before = try XCTUnwrap(frontBar()).frame
            if before.minY <= screen.minY + screen.height * 0.15 { break }
            let grabber = app.otherElements.matching(NSPredicate(format: "label == %@", "Grabber"))
                .allElementsBoundByIndex.last {
                    $0.exists && $0.frame.height < 50
                        && abs($0.frame.midX - before.midX) < before.width * 0.1
                        && $0.frame.minY >= before.minY - 40
                        && $0.frame.maxY <= before.maxY
                }
            let start = grabber.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
                ?? CGPoint(x: before.midX, y: before.minY + min(6, before.height / 4))
            dragFromObservedFrame(from: start,
                                  to: CGPoint(x: start.x, y: screen.minY + screen.height * 0.08))
            if waitUntil(timeout: 3, {
                guard let updated = frontBar() else { return false }
                return updated.frame.minY < before.minY - screen.height * 0.1
            }) { break }
        }
        let header = try XCTUnwrap(frontBar()).frame
        // A regular-width iPad form can remain centered at its largest detent.
        // Compact phone sheets must actually leave their medium-detent position.
        if screen.width < 600, initial.minY > screen.minY + screen.height * 0.15 {
            XCTAssertLessThanOrEqual(header.minY, screen.minY + screen.height * 0.15,
                                     "Expand the phone History sheet before its largest-text capture")
        }
        let empty = app.descendants(matching: .any).matching(identifier: "history.empty").firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        var viewport = empty.frame.intersection(screen)
        let top = max(viewport.minY, header.maxY)
        viewport = CGRect(x: viewport.minX, y: top, width: viewport.width,
                          height: max(0, viewport.maxY - top)).insetBy(dx: 0, dy: 8)
        let description = app.staticTexts["Your connectivity checks will appear here"]
        XCTAssertTrue(description.exists && description.isHittable)
        XCTAssertTrue(verticallyContains(description.frame, in: viewport),
                      "The empty-History description must be inside the expanded content viewport")
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
