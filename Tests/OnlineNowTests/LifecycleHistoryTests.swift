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
        container.mainContext.autosaveEnabled = false
        let history = HistoryManager()
        history.configure(with: container.mainContext)
        XCTAssertNil(history.errorMessage)
        return (history, container)
    }

    func testRetentionAndStatisticsUseAllRetainedChecks() throws {
        let (history, container) = try makeHistory()
        defer { withExtendedLifetime(container) {} }
        for index in 0..<105 {
            history.saveCheck(ConnectivityCheck(
                timestamp: Date(timeIntervalSince1970: Double(index)),
                isConnected: index >= 30, connectionType: "WiFi", isReachable: index >= 50,
                speedMbps: index >= 50 ? 50 : nil
            ))
            XCTAssertNil(history.errorMessage, "Saving check \(index) must succeed")
            if [0, 99, 100, 104].contains(index) {
                // A fresh context sees only committed rows, not pending inserts in
                // the manager's context. Cover below, at, and above the limit.
                let reader = ModelContext(container)
                XCTAssertEqual(try reader.fetchCount(FetchDescriptor<ConnectivityCheck>()),
                               min(index + 1, 100), "Stored count after check \(index)")
            }
        }
        let reader = ModelContext(container)
        let stored = try reader.fetch(FetchDescriptor<ConnectivityCheck>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))
        XCTAssertEqual(stored.map(\.timestamp),
                       (5..<105).reversed().map { Date(timeIntervalSince1970: Double($0)) })
        let statistics = history.getStatistics()
        XCTAssertEqual(history.recentChecks.count, 20)
        XCTAssertEqual(statistics.totalChecks, 100)
        XCTAssertEqual(statistics.onlineCount, 55)
        XCTAssertEqual(statistics.offlineCount, 25)
        XCTAssertEqual(statistics.limitedCount, 20)
        XCTAssertEqual(statistics.averageSpeedMbps, 50)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ConnectivityCheck>()), 100)
        XCTAssertTrue(history.clearHistory())
        XCTAssertNil(history.errorMessage)
        XCTAssertEqual(history.getStatistics().totalChecks, 0)
        XCTAssertNil(history.lastCheck)
        let clearedReader = ModelContext(container)
        XCTAssertEqual(try clearedReader.fetchCount(FetchDescriptor<ConnectivityCheck>()), 0)
    }

    func testHistoryKeepsDistinctTCPAndHTTPTimingsAndEscapesCSV() throws {
        let (history, container) = try makeHistory()
        defer { withExtendedLifetime(container) {} }
        withExtendedLifetime(container) {
            history.recordCheck(
                isConnected: true, connectionType: .wifi, isReachable: false,
                rttMs: 12, responseTimeMs: 55, errorMessage: "=test, \"quoted\"\nnext"
            )
        }
        XCTAssertNil(history.errorMessage)
        let reader = ModelContext(container)
        let stored = try reader.fetch(FetchDescriptor<ConnectivityCheck>())
        XCTAssertEqual(stored.count, 1, "The first saved check must survive retention pruning")
        let saved = try XCTUnwrap(stored.first)
        XCTAssertEqual(history.lastCheck?.id, saved.id)
        XCTAssertEqual(saved.rttMs, 12)
        XCTAssertEqual(saved.responseTimeMs, 55)
        XCTAssertEqual(saved.measurementMethod, "TCP")
        let csv = try history.exportCSV()
        XCTAssertNil(history.errorMessage)
        XCTAssertTrue(csv.contains("tcp_rtt_ms,http_response_ms"))
        XCTAssertTrue(csv.contains("\"limited\""))
        XCTAssertTrue(csv.contains("\"12.0\",\"55.0\""))
        XCTAssertTrue(csv.contains("\"'=test, \"\"quoted\"\"\nnext\""))
    }

    func testUnconfiguredHistoryReportsFailureAndRecoversAfterConfiguration() throws {
        let history = HistoryManager()
        let check = ConnectivityCheck(isConnected: true, connectionType: "WiFi", isReachable: true)
        history.saveCheck(check)
        XCTAssertNotNil(history.errorMessage)
        XCTAssertNil(history.lastCheck)
        XCTAssertThrowsError(try history.exportCSV())
        XCTAssertNotNil(history.errorMessage)

        let schema = Schema([ConnectivityCheck.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ])
        defer { withExtendedLifetime(container) {} }
        container.mainContext.autosaveEnabled = false
        history.configure(with: container.mainContext)
        XCTAssertNil(history.errorMessage)
        history.saveCheck(check)
        XCTAssertNil(history.errorMessage)
        let reader = ModelContext(container)
        let stored = try reader.fetch(FetchDescriptor<ConnectivityCheck>())
        XCTAssertEqual(stored.map(\.id), [check.id])
        XCTAssertEqual(history.lastCheck?.id, check.id)
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

    func testMissingOrFailedSpeedMeasurementDoesNotInventQuality() async {
        let viewModel = makeViewModel()
        viewModel.latencyMeasurement = {
            LatencyResult(rttMs: nil, method: .tcp, endpoint: "Test", error: "Unavailable")
        }
        viewModel.speedMeasurement = {
            SpeedTestResult(speedMbps: nil, bytesDownloaded: 0, durationSeconds: 0, error: nil)
        }
        viewModel.startMonitoring()
        viewModel.applyNetworkSnapshot(connectedSnapshot, automaticallyCheck: false)
        await viewModel.fullCheck()
        XCTAssertEqual(viewModel.state, .online)
        XCTAssertEqual(viewModel.signalQuality, "Unknown")
        viewModel.speedMeasurement = {
            SpeedTestResult(speedMbps: 100, bytesDownloaded: 1_000_000,
                            durationSeconds: 1, error: "Incomplete download")
        }
        await viewModel.fullCheck()
        XCTAssertEqual(viewModel.signalQuality, "Unknown")
        XCTAssertEqual(viewModel.errorMessage, "Incomplete download")
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
