import Foundation
import XCTest
import StoreKitTest

final class OnlineNowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline"]
    }

    func testOfflineRefreshAndHistoryNavigation() throws {
        app.launch()
        let refresh = app.buttons["connectivity.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        refresh.tap()
        XCTAssertTrue(refresh.waitForEnabled(timeout: 10))
        app.buttons["navigation.history"].tap()
        XCTAssertTrue(app.otherElements["history.empty"].waitForExistence(timeout: 5)
                      || app.staticTexts["history.empty"].exists)
        attachScreenshot(named: "Online Now - Empty history")
        app.buttons["Done"].tap()
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
    }

    func testDonationPurchaseAndRepeatedTip() throws {
        let store = try SKTestSession(configurationFileNamed: "Configuration")
        store.resetToDefaultState()
        store.disableDialogs = true
        store.clearTransactions()
        defer { store.clearTransactions(); store.resetToDefaultState() }
        app.launch()
        app.buttons["navigation.tipJar"].tap()
        let purchase = app.buttons["tipJar.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.waitForEnabled(timeout: 10))
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
        attachScreenshot(named: "Online Now - Tip jar after repeat tips", exportForReview: true)
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
