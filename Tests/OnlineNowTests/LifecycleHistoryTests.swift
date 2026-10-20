#if canImport(SwiftData) && !SWIFT_PACKAGE
import XCTest
import SwiftData
@testable import OnlineNow

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class LifecycleHistoryTests: XCTestCase {
    private func makeHistory() throws -> (HistoryManager, ModelContainer) {
        let schema = Schema([ConnectivityCheck.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ])
        let history = HistoryManager()
        history.configure(with: container.mainContext)
        return (history, container)
    }

    func testRetentionAndStatisticsUseAllRetainedChecks() throws {
        let (history, container) = try makeHistory()
        for index in 0..<105 {
            history.saveCheck(ConnectivityCheck(
                timestamp: Date(timeIntervalSince1970: Double(index)),
                isConnected: index >= 30, connectionType: "WiFi", isReachable: index >= 50,
                speedMbps: index >= 50 ? 50 : nil
            ))
        }
        let statistics = history.getStatistics()
        XCTAssertEqual(history.recentChecks.count, 20)
        XCTAssertEqual(statistics.totalChecks, 100)
        XCTAssertEqual(statistics.onlineCount, 55)
        XCTAssertEqual(statistics.offlineCount, 25)
        XCTAssertEqual(statistics.limitedCount, 20)
        XCTAssertEqual(statistics.averageSpeedMbps, 50)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ConnectivityCheck>()), 100)
        XCTAssertTrue(history.clearHistory())
        XCTAssertEqual(history.getStatistics().totalChecks, 0)
        XCTAssertNil(history.lastCheck)
    }

    func testHistoryKeepsDistinctTCPAndHTTPTimingsAndEscapesCSV() throws {
        let (history, container) = try makeHistory()
        withExtendedLifetime(container) {
            history.recordCheck(
                isConnected: true, connectionType: .wifi, isReachable: false,
                rttMs: 12, responseTimeMs: 55, errorMessage: "=test, \"quoted\"\nnext"
            )
        }
        XCTAssertEqual(history.lastCheck?.rttMs, 12)
        XCTAssertEqual(history.lastCheck?.responseTimeMs, 55)
        XCTAssertEqual(history.lastCheck?.measurementMethod, "TCP")
        let csv = try history.exportCSV()
        XCTAssertTrue(csv.contains("tcp_rtt_ms,http_response_ms"))
        XCTAssertTrue(csv.contains("\"limited\""))
        XCTAssertTrue(csv.contains("\"12.0\",\"55.0\""))
        XCTAssertTrue(csv.contains("\"'=test, \"\"quoted\"\"\nnext\""))
    }

    func testCompletedManualCheckLeavesBusyStateAndSpeedIsExplicit() async {
        let viewModel = makeViewModel()
        var speedTests = 0
        viewModel.speedMeasurement = {
            speedTests += 1
            return SpeedTestResult(speedMbps: 20, bytesDownloaded: 1_000_000, durationSeconds: 0.4, error: nil)
        }
        viewModel.startMonitoring()
        viewModel.applyNetworkSnapshot(connectedSnapshot, automaticallyCheck: false)
        await viewModel.quickCheck()
        XCTAssertEqual(viewModel.state, .online)
        XCTAssertFalse(viewModel.isPerformingCheck)
        XCTAssertFalse(viewModel.isPerformingSpeedTest)
        XCTAssertEqual(speedTests, 0)
        XCTAssertEqual(viewModel.signalQuality, "Excellent")
        await viewModel.fullCheck()
        XCTAssertEqual(viewModel.state, .online)
        XCTAssertFalse(viewModel.isPerformingCheck)
        XCTAssertEqual(speedTests, 1)
        viewModel.stopMonitoring()
    }

    func testMissingMeasurementsDoNotInventFairQuality() async {
        let viewModel = makeViewModel()
        viewModel.latencyMeasurement = {
            LatencyResult(rttMs: nil, method: .tcp, endpoint: "Test", error: "Unavailable")
        }
        viewModel.startMonitoring()
        viewModel.applyNetworkSnapshot(connectedSnapshot, automaticallyCheck: false)
        await viewModel.quickCheck()
        XCTAssertEqual(viewModel.state, .online)
        XCTAssertEqual(viewModel.signalQuality, "Unknown")
        viewModel.stopMonitoring()
    }

    func testDisconnectDiscardsInflightReachabilityAndClearsMeasurements() async {
        let viewModel = makeViewModel()
        var continuation: CheckedContinuation<ReachabilityResult, Never>?
        viewModel.reachabilityCheck = {
            await withCheckedContinuation { continuation = $0 }
        }
        viewModel.startMonitoring()
        viewModel.applyNetworkSnapshot(connectedSnapshot, automaticallyCheck: false)
        let task = Task { await viewModel.quickCheck() }
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        guard continuation != nil else {
            XCTFail("The reachability operation did not start")
            task.cancel()
            viewModel.stopMonitoring()
            return
        }
        viewModel.applyNetworkSnapshot(NetworkPathSnapshot(
            isConnected: false, connectionType: .none, isVPNActive: false,
            isConstrained: false, isExpensive: false
        ), automaticallyCheck: false)
        continuation?.resume(returning: ReachabilityResult(isReachable: true, responseTimeMs: 20, error: nil))
        await task.value
        XCTAssertEqual(viewModel.state, .offline)
        XCTAssertFalse(viewModel.isReachable)
        XCTAssertNil(viewModel.rttMs)
        XCTAssertNil(viewModel.responseTimeMs)
        XCTAssertNil(viewModel.speedResult)
        XCTAssertFalse(viewModel.isPerformingCheck)
        viewModel.stopMonitoring()
    }

    func testMonitorCanStopAndRestart() {
        let monitor = NetworkMonitor()
        monitor.start()
        monitor.start()
        XCTAssertTrue(monitor.isMonitoring)
        monitor.stop()
        XCTAssertFalse(monitor.isMonitoring)
        monitor.start()
        XCTAssertTrue(monitor.isMonitoring)
        monitor.stop()
    }

    private var connectedSnapshot: NetworkPathSnapshot {
        NetworkPathSnapshot(isConnected: true, connectionType: .wifi, isVPNActive: false,
                            isConstrained: false, isExpensive: false)
    }

    private func makeViewModel() -> ConnectivityViewModel {
        let defaults = UserDefaults(suiteName: "OnlineNow.LifecycleTests.\(UUID().uuidString)")!
        let viewModel = ConnectivityViewModel(
            networkMonitor: SilentNetworkMonitor(),
            tippingManager: TippingManager(defaults: defaults, startsStoreKit: false)
        )
        viewModel.reachabilityCheck = {
            ReachabilityResult(isReachable: true, responseTimeMs: 20, error: nil)
        }
        viewModel.latencyMeasurement = {
            LatencyResult(rttMs: 10, method: .tcp, endpoint: "Test", error: nil)
        }
        viewModel.endpointCheck = { _ in true }
        return viewModel
    }
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
private final class SilentNetworkMonitor: NetworkMonitor {
    override func start() {}
    override func stop() {}
}
#endif
