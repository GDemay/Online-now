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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
