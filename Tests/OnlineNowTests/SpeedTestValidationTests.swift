import Foundation
import XCTest

@testable import OnlineNow

/// Tests for validating speed test and latency measurements
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
final class SpeedTestValidationTests: XCTestCase {

    // MARK: - Speed Test Validation

    func testSpeedTestDownloadsCorrectAmount() async throws {
        let service = SpeedTestService()
        let result = await service.measureSpeed(quick: true)

        // Check that test completed
        XCTAssertNotNil(result.speedMbps, "Speed test should complete successfully")

        // Check that bytes downloaded is close to expected (5MB for quick test)
        // Allow some variance due to headers and early termination
        let expectedBytes = 5_000_000
        let variance = 0.2  // 20% variance
        let lowerBound = Int(Double(expectedBytes) * (1 - variance))
        let upperBound = Int(Double(expectedBytes) * (1 + variance))

        XCTAssertTrue(
            result.bytesDownloaded >= lowerBound && result.bytesDownloaded <= upperBound,
            "Bytes downloaded (\(result.bytesDownloaded)) should be close to \(expectedBytes)"
        )

        // Check that duration is reasonable (should take at least 0.1 seconds)
        XCTAssertGreaterThan(result.durationSeconds, 0.1, "Test should take at least 0.1 seconds")

        // Check that speed is calculated correctly
        if let speed = result.speedMbps {
            let expectedSpeed =
                (Double(result.bytesDownloaded) * 8) / result.durationSeconds / 1_000_000
            let speedVariance = abs(speed - expectedSpeed) / expectedSpeed

            XCTAssertLessThan(
                speedVariance, 0.01,
                "Calculated speed (\(speed)) should match expected (\(expectedSpeed))"
            )
        }
    }

    func testSpeedTestCalculation() {
        // Test the speed calculation formula
        let bytesDownloaded = 5_000_000  // 5MB
        let durationSeconds = 2.0

        let expectedSpeedMbps = (Double(bytesDownloaded) * 8) / durationSeconds / 1_000_000
        // Expected: (5,000,000 * 8) / 2 / 1,000,000 = 20 Mbps

        XCTAssertEqual(
            expectedSpeedMbps, 20.0, accuracy: 0.01, "Speed calculation should be correct")
    }

    // MARK: - Latency Measurement Validation

    func testTCPLatencyMeasurement() async throws {
        let service = LatencyMeasurementService()
        let result = await service.measureTCPLatency(to: .cloudflare)

        // Check that measurement succeeded
        XCTAssertNotNil(result.rttMs, "Latency measurement should succeed")

        if let rtt = result.rttMs {
            // Network latency should be reasonable (1ms to 1000ms)
            XCTAssertGreaterThan(rtt, 0, "Latency should be positive")
            XCTAssertLessThan(rtt, 1000, "Latency should be less than 1 second")

            print("✅ TCP Latency to \(result.endpoint): \(result.formattedLatency)")
        } else {
            XCTFail("Latency measurement failed: \(result.error ?? "unknown error")")
        }
    }

    func testAverageLatencyMeasurement() async throws {
        let service = LatencyMeasurementService()
        let result = await service.measureAverageLatency(samples: 3)

        XCTAssertNotNil(result.rttMs, "Average latency should be measured")

        if let rtt = result.rttMs {
            print(
                "✅ Average TCP Latency: \(result.formattedLatency) (\(result.qualityDescription))")
        }
    }

    func testHTTPResponseTimeLongerThanTCP() async throws {
        let service = LatencyMeasurementService()

        // Measure TCP latency
        let tcpResult = await service.measureTCPLatency(to: .google)

        // Measure HTTP response time
        let httpResult = await service.measureHTTPResponseTime(url: "https://www.google.com")

        guard let tcpTime = tcpResult.rttMs, let httpTime = httpResult.rttMs else {
            XCTFail("Both measurements should succeed")
            return
        }

        // HTTP should take longer than TCP (due to TLS handshake and server processing)
        XCTAssertGreaterThan(
            httpTime, tcpTime,
            "HTTP response time (\(httpTime)ms) should be greater than TCP RTT (\(tcpTime)ms)"
        )

        print("✅ TCP RTT: \(String(format: "%.0f ms", tcpTime))")
        print("✅ HTTP Response: \(String(format: "%.0f ms", httpTime))")
        print("✅ Overhead: \(String(format: "%.0f ms", httpTime - tcpTime))")
    }

    // MARK: - Diagnostic Service Validation

    func testDiagnosticLatencyValidation() async throws {
        let service = DiagnosticService()
        let result = await service.validateLatency(host: "1.1.1.1")

        print("\n📊 Diagnostic Result:")
        print(result.summary)

        // Check that app measurement was made
        XCTAssertFalse(result.appMeasurement.contains("Failed"), "App measurement should succeed")

        // Print details
        for (key, value) in result.details {
            print("  \(key): \(value)")
        }
    }

    // MARK: - Integration Tests

    func testReachabilityServiceResponseTime() async throws {
        let service = ReachabilityService()
        let result = await service.checkReachability()

        XCTAssertTrue(result.isReachable, "Internet should be reachable")
        XCTAssertGreaterThan(result.responseTimeMs, 0, "Response time should be positive")

        print("✅ Reachability check: \(result.isReachable)")
        print("✅ HTTP Response time: \(String(format: "%.0f ms", result.responseTimeMs))")
    }
}

// MARK: - Manual Terminal Comparison Guide

/*
 HOW TO COMPARE WITH TERMINAL TOOLS:

 1. LATENCY COMPARISON (ping):

    Terminal command:
    ```bash
    ping -c 10 1.1.1.1
    ```

    Look for: "round-trip min/avg/max/stddev = X/Y/Z/W ms"
    Compare the 'avg' value with app's rttMs

    Expected difference:
    - TCP RTT (app) should be slightly higher than ICMP ping (5-15ms overhead)
    - Both should be in same order of magnitude

 2. SPEED TEST COMPARISON:

    Install speedtest-cli (macOS):
    ```bash
    brew install speedtest-cli
    ```

    Run speed test:
    ```bash
    speedtest-cli --simple
    ```

    Look for: "Download: X.XX Mbit/s"
    Compare with app's speedMbps

    Expected difference:
    - Results should be within 20% of each other
    - Cloudflare's endpoint may give different speeds than speedtest.net

 3. ALTERNATIVE LATENCY TEST (curl timing):

    ```bash
    curl -w "@-" -o /dev/null -s "https://www.google.com" <<'EOF'
    time_namelookup:  %{time_namelookup}s\n
    time_connect:     %{time_connect}s\n
    time_appconnect:  %{time_appconnect}s\n
    time_total:       %{time_total}s\n
    EOF
    ```

    Compare:
    - time_connect (TCP) ≈ app's rttMs
    - time_total ≈ app's responseTimeMs

 4. RUN DIAGNOSTIC MODE IN APP:

    In your app, enable diagnostic mode:
    ```swift
    viewModel.isDiagnosticMode = true
    await viewModel.runDiagnostics()
    ```

    This will automatically compare app measurements with system ping (macOS only)
    and print detailed comparison results.
 */
