import Foundation
import XCTest
@testable import OnlineNow

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
final class NetworkRetryRegressionTests: XCTestCase {
    func testInvalidConfigurationCannotTrap() {
        let config = NetworkRetryConfiguration(
            maxRetries: 0, baseDelay: -.infinity, maxDelay: -.infinity, timeout: .nan)
        XCTAssertEqual(config.maxRetries, 1)
        XCTAssertEqual(config.baseDelay, 0)
        XCTAssertTrue(config.maxDelay.isFinite)
        XCTAssertEqual(config.timeout, 0)
    }

    func testRetriesUseConfiguredAttemptLimit() async {
        let attempts = AttemptCounter()
        let retry = NetworkRetry(reachabilityService: StubReachability(online: true))
        let result: NetworkRetryResult<Int> = await retry.execute(
            description: "Retryable read",
            configuration: .init(maxRetries: 3, baseDelay: 0, waitForConnectivity: false)
        ) {
            await attempts.increment()
            throw TestFailure.expected
        }
        let count = await attempts.count
        XCTAssertEqual(count, 3)
        guard let error = result.error, case .maxRetriesExceeded(let reported, _) = error else {
            return XCTFail("Expected bounded retries")
        }
        XCTAssertEqual(reported, 3)
    }

    func testTimeoutIncludesWaitingForConnectivity() async {
        let attempts = AttemptCounter()
        let retry = NetworkRetry(reachabilityService: StubReachability(online: false))
        let result: NetworkRetryResult<Int> = await retry.execute(
            description: "Offline read", configuration: .init(timeout: 0.02)
        ) {
            await attempts.increment()
            return 1
        }
        guard let error = result.error, case .timeout = error else { return XCTFail("Expected timeout") }
        let count = await attempts.count
        XCTAssertEqual(count, 0, "Offline timeout must not run the operation")
    }

    func testTimeoutCancelsInFlightOperation() async {
        let attempts = AttemptCounter()
        let retry = NetworkRetry(reachabilityService: StubReachability(online: true))
        let result: NetworkRetryResult<Int> = await retry.execute(
            description: "Slow read",
            configuration: .init(waitForConnectivity: false, timeout: 0.02)
        ) {
            await attempts.increment()
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return 1
        }
        guard let error = result.error, case .timeout = error else { return XCTFail("Expected timeout") }
        let count = await attempts.count
        XCTAssertEqual(count, 1)
    }

    func testCancellationStopsBackoffWithoutAnotherAttempt() async throws {
        let attempts = AttemptCounter()
        let retry = NetworkRetry(reachabilityService: StubReachability(online: true))
        let worker = Task {
            await retry.execute(
                description: "Cancelled read",
                configuration: .init(maxRetries: 3, baseDelay: 100, maxDelay: 100,
                                     waitForConnectivity: false)
            ) { () async throws -> Int in
                await attempts.increment()
                throw TestFailure.expected
            }
        }
        for _ in 0..<100 {
            if await attempts.count > 0 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        worker.cancel()
        let result = await worker.value
        guard let error = result.error, case .cancelled = error else { return XCTFail("Expected cancellation") }
        let count = await attempts.count
        XCTAssertEqual(count, 1)
    }

    func testQueuedOperationUsesRetryConfiguration() async throws {
        let attempts = AttemptCounter()
        let retry = NetworkRetry(reachabilityService: StubReachability(online: true))
        _ = await retry.queue(
            description: "Queued read",
            configuration: .init(maxRetries: 3, baseDelay: 0, waitForConnectivity: false)
        ) { () async throws -> Int in
            await attempts.increment()
            throw TestFailure.expected
        }
        for _ in 0..<200 {
            if await retry.queuedCount == 0 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let count = await attempts.count
        let queued = await retry.queuedCount
        XCTAssertEqual(count, 3, "Queued work must apply its retry configuration")
        XCTAssertEqual(queued, 0)
    }

    func testCancelledQueuedWorkNeverRunsWhenConnectivityReturns() async throws {
        let attempts = AttemptCounter()
        let connectivity = StubReachability(online: false)
        let retry = NetworkRetry(reachabilityService: connectivity)
        let id = await retry.queue(description: "Cancel before online") {
            await attempts.increment()
            return 1
        }
        let cancelled = await retry.cancel(operationId: id)
        XCTAssertTrue(cancelled)
        await connectivity.setOnline(true)
        await retry.startMonitoringIfNeeded()
        try await Task.sleep(nanoseconds: 10_000_000)
        let count = await attempts.count
        let queued = await retry.queuedCount
        XCTAssertEqual(count, 0)
        XCTAssertEqual(queued, 0)
    }

    private enum TestFailure: Error { case expected }

    private actor AttemptCounter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    private actor StubReachability: ReachabilityChecking {
        private var online: Bool
        init(online: Bool) { self.online = online }
        func setOnline(_ value: Bool) { online = value }
        func checkReachability() async -> ReachabilityResult {
            ReachabilityResult(isReachable: online, responseTimeMs: 1, error: nil)
        }
        func detectCaptivePortal() async -> CaptivePortalResult { .noCaptivePortal }
    }
}
