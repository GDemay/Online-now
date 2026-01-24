import XCTest
@testable import OnlineNow

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
final class OnlineNowTests: XCTestCase {

    // MARK: - MockNetworkMonitor Tests

    func testMockNetworkMonitorDefaultsToConnected() async {
        let mock = MockNetworkMonitor()
        XCTAssertEqual(mock.status, .connected)
        XCTAssertEqual(mock.metadata.connectionType, .wifi)
    }

    func testMockNetworkMonitorScenarios() async {
        // Test disconnected scenario
        let disconnectedMock = MockNetworkMonitor(scenario: .disconnected)
        XCTAssertEqual(disconnectedMock.status, .disconnected)
        XCTAssertEqual(disconnectedMock.metadata.connectionType, .none)

        // Test captive portal scenario
        let captiveMock = MockNetworkMonitor(scenario: .captivePortal)
        XCTAssertEqual(captiveMock.status, .captivePortal)

        // Test slow connection scenario
        let slowMock = MockNetworkMonitor(scenario: .slowConnection)
        XCTAssertEqual(slowMock.status, .connected)
        XCTAssertEqual(slowMock.metadata.signalQuality, .poor)

        // Test cellular expensive scenario
        let cellularMock = MockNetworkMonitor(scenario: .cellularExpensive)
        XCTAssertTrue(cellularMock.metadata.isExpensive)
        XCTAssertEqual(cellularMock.metadata.connectionType, .cellular)

        // Test VPN active scenario
        let vpnMock = MockNetworkMonitor(scenario: .vpnActive)
        XCTAssertTrue(vpnMock.metadata.isUsingTunnel)

        // Test low data mode scenario
        let lowDataMock = MockNetworkMonitor(scenario: .lowDataMode)
        XCTAssertTrue(lowDataMock.metadata.isConstrained)
    }

    func testMockNetworkMonitorStateChanges() async {
        let mock = MockNetworkMonitor()

        // Change status
        mock.setStatus(.disconnected)
        XCTAssertEqual(mock.status, .disconnected)

        // Apply scenario
        mock.apply(scenario: .captivePortal)
        XCTAssertEqual(mock.status, .captivePortal)

        // Resolve captive portal
        mock.resolveCaptivePortal()
        XCTAssertEqual(mock.status, .connected)
    }

    // MARK: - ConnectivityStatus Tests

    func testConnectivityStatusProperties() {
        XCTAssertTrue(ConnectivityStatus.connected.hasInternet)
        XCTAssertFalse(ConnectivityStatus.disconnected.hasInternet)
        XCTAssertFalse(ConnectivityStatus.captivePortal.hasInternet)
        XCTAssertFalse(ConnectivityStatus.localOnly.hasInternet)

        XCTAssertTrue(ConnectivityStatus.connected.hasLocalNetwork)
        XCTAssertTrue(ConnectivityStatus.localOnly.hasLocalNetwork)
        XCTAssertTrue(ConnectivityStatus.captivePortal.hasLocalNetwork)
        XCTAssertFalse(ConnectivityStatus.disconnected.hasLocalNetwork)
    }

    // MARK: - NetworkMetadata Tests

    func testNetworkMetadataEmpty() {
        let empty = NetworkMetadata.empty
        XCTAssertEqual(empty.connectionType, .none)
        XCTAssertFalse(empty.isExpensive)
        XCTAssertFalse(empty.isConstrained)
        XCTAssertFalse(empty.isUsingTunnel)
        XCTAssertNil(empty.latencyMs)
        XCTAssertNil(empty.speedMbps)
    }

    // MARK: - ReachabilityResult Tests

    func testReachabilityResult() {
        let successResult = ReachabilityResult(isReachable: true, latencyMs: 25.0, error: nil)
        XCTAssertTrue(successResult.isReachable)
        XCTAssertEqual(successResult.latencyMs, 25.0)
        XCTAssertNil(successResult.error)

        let failureResult = ReachabilityResult(isReachable: false, latencyMs: 0, error: "No connection")
        XCTAssertFalse(failureResult.isReachable)
        XCTAssertEqual(failureResult.error, "No connection")
    }

    // MARK: - CaptivePortalResult Tests

    func testCaptivePortalResult() {
        let noCaptive = CaptivePortalResult.noCaptivePortal
        XCTAssertFalse(noCaptive.isCaptivePortal)
        XCTAssertNil(noCaptive.portalURL)

        let captive = CaptivePortalResult(
            isCaptivePortal: true,
            portalURL: URL(string: "https://portal.hotel.com/login"),
            error: nil
        )
        XCTAssertTrue(captive.isCaptivePortal)
        XCTAssertNotNil(captive.portalURL)
    }

    // MARK: - NetworkRetryConfiguration Tests

    func testNetworkRetryConfigurations() {
        let quick = NetworkRetryConfiguration.quick
        XCTAssertEqual(quick.maxRetries, 2)
        XCTAssertEqual(quick.baseDelay, 0.5)
        XCTAssertTrue(quick.waitForConnectivity)

        let critical = NetworkRetryConfiguration.critical
        XCTAssertEqual(critical.maxRetries, 5)
        XCTAssertEqual(critical.timeout, 300)

        let background = NetworkRetryConfiguration.background
        XCTAssertEqual(background.maxRetries, 10)
        XCTAssertNil(background.timeout)
    }

    // MARK: - SignalQuality Tests

    func testSignalQualityColors() {
        XCTAssertEqual(SignalQuality.excellent.colorName, "green")
        XCTAssertEqual(SignalQuality.good.colorName, "blue")
        XCTAssertEqual(SignalQuality.fair.colorName, "orange")
        XCTAssertEqual(SignalQuality.poor.colorName, "red")
        XCTAssertEqual(SignalQuality.unknown.colorName, "gray")
    }

    // MARK: - ConnectionType Tests

    func testConnectionTypeIcons() {
        XCTAssertEqual(ConnectionType.wifi.icon, "wifi")
        XCTAssertEqual(ConnectionType.cellular.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(ConnectionType.ethernet.icon, "cable.connector")
        XCTAssertEqual(ConnectionType.none.icon, "wifi.slash")
    }
}
