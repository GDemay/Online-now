import XCTest
@testable import OnlineNow

@MainActor
final class BannerLifecycleTests: XCTestCase {
    func testRepeatedConnectedPollDoesNotRedisplayDismissedBanner() async throws {
        let configuration = ConnectivityBannerConfiguration(
            displayMode: .always, hapticFeedback: false, autoDismissDelay: 0
        )
        let model = ConnectivityBannerViewModel(configuration: configuration)
        model.updateStatus(.connected, latency: 20)
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertFalse(model.isVisible)

        // The normal five-second poll should update timing without flashing the banner again.
        model.updateStatus(.connected, latency: 30)
        XCTAssertFalse(model.isVisible)
        XCTAssertEqual(model.metadata.latencyMs, 30)

        model.updateStatus(.disconnected, latency: 0)
        XCTAssertTrue(model.isVisible)
        XCTAssertNil(model.metadata.latencyMs)
    }

    func testStoppingMonitoringCancelsScheduledDismissal() async throws {
        let model = ConnectivityBannerViewModel(configuration: .init(
            displayMode: .always, hapticFeedback: false, autoDismissDelay: 0.02
        ))
        model.updateStatus(.connected, latency: 20)
        model.stopMonitoring()
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertTrue(model.isVisible)
    }

    func testNonfiniteLatencyAndLocalOnlyState() {
        let model = ConnectivityBannerViewModel(configuration: .init(displayMode: .problemsOnly, hapticFeedback: false))
        model.updateStatus(.connected, latency: .infinity)
        XCTAssertNil(model.metadata.latencyMs)
        model.updateStatus(.localOnly, latency: 0)
        XCTAssertTrue(model.isVisible)
        XCTAssertNil(model.metadata.latencyMs)
    }
}
