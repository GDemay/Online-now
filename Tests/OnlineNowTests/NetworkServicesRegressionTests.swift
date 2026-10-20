import Foundation
import XCTest
@testable import OnlineNow

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
final class NetworkServicesRegressionTests: XCTestCase {
    private let speedURL = URL(string: "https://speed.cloudflare.com/__down?bytes=5000000")!

    private func response(_ url: URL, status: Int = 200,
                          headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    }

    func testThroughputUsesWholeMeasuredTransferWithoutInventedWarmup() {
        // The old implementation subtracted an estimated warmup, inflating this result.
        let result = SpeedTestService.result(bytes: 5_000_000, duration: 2,
            expectedBytes: 5_000_000, response: response(speedURL))
        XCTAssertEqual(result.speedMbps ?? 0, 20, accuracy: 0.0001)
        XCTAssertEqual(result.bytesDownloaded, 5_000_000)
        XCTAssertEqual(result.durationSeconds, 2)
        XCTAssertNil(result.error)
    }

    func testPortalErrorPagesAndIncompleteDownloadsNeverBecomeSpeedResults() {
        let invalidResponses = [
            response(speedURL, headers: ["Content-Type": "text/html"]),
            response(speedURL, status: 503),
            response(speedURL, headers: ["Content-Encoding": "gzip"]),
            response(URL(string: "https://login.example.com")!)
        ]
        for http in invalidResponses {
            let result = SpeedTestService.result(bytes: 5_000_000, duration: 2,
                expectedBytes: 5_000_000, response: http)
            XCTAssertNil(result.speedMbps)
            XCTAssertNotNil(result.error)
        }
        for bytes in [0, 10_000, 4_999_999] {
            XCTAssertNil(SpeedTestService.result(bytes: bytes, duration: 2,
                expectedBytes: 5_000_000, response: response(speedURL)).speedMbps)
        }
    }

    func testInvalidDurationsNeverProduceInfiniteOrNaNThroughput() {
        for duration in [0, -1, Double.infinity, Double.nan] {
            XCTAssertNil(SpeedTestService.result(bytes: 5_000_000, duration: duration,
                expectedBytes: 5_000_000, response: response(speedURL)).speedMbps)
        }
        XCTAssertEqual(SpeedTestService.speedDescription(.infinity), "Unknown")
        XCTAssertEqual(SpeedTestService.speedDescription(-10), "Unknown")
    }

    func testReachabilityRequiresProviderSpecificResponse() {
        let google = URL(string: "https://www.google.com/generate_204")!
        XCTAssertTrue(ReachabilityService.isExpectedInternetResponse(data: Data(),
            response: response(google, status: 204), for: google))
        XCTAssertFalse(ReachabilityService.isExpectedInternetResponse(data: Data("login".utf8),
            response: response(google), for: google))
        XCTAssertFalse(ReachabilityService.isExpectedInternetResponse(data: Data(),
            response: response(google, status: 302), for: google))

        let cloudflare = URL(string: "https://cloudflare.com/cdn-cgi/trace")!
        XCTAssertFalse(ReachabilityService.isExpectedInternetResponse(data: Data("Success login".utf8),
            response: response(cloudflare), for: cloudflare))
        XCTAssertTrue(ReachabilityService.isExpectedInternetResponse(
            data: Data("h=cloudflare.com\nip=203.0.113.1\n".utf8),
            response: response(cloudflare), for: cloudflare))
        XCTAssertFalse(ReachabilityService.isExpectedInternetResponse(
            data: Data("h=cloudflare.com\nip=203.0.113.1\n".utf8),
            response: response(URL(string: "https://login.example.com")!), for: cloudflare))
    }

    func testCaptivePortalRedirectUsesLocationAndRejectsUnsafeSchemes() {
        let url = URL(string: "http://captive.apple.com/hotspot-detect.html")!
        let redirected = ReachabilityService.captivePortalResult(data: Data(),
            response: response(url, status: 302, headers: ["Location": "https://wifi.example.com/login"]),
            requestedURL: url)
        XCTAssertTrue(redirected.isCaptivePortal)
        XCTAssertEqual(redirected.portalURL?.absoluteString, "https://wifi.example.com/login")
        let unsafe = ReachabilityService.captivePortalResult(data: Data(),
            response: response(url, status: 302, headers: ["Location": "javascript:alert(1)"]),
            requestedURL: url)
        XCTAssertTrue(unsafe.isCaptivePortal)
        XCTAssertNil(unsafe.portalURL)
    }

    func testCaptivePortalDoesNotTreatWordSuccessOnLoginPageAsInternet() {
        let url = URL(string: "http://captive.apple.com/hotspot-detect.html")!
        let login = ReachabilityService.captivePortalResult(
            data: Data("<html>Success! Please sign in.</html>".utf8),
            response: response(url), requestedURL: url)
        XCTAssertTrue(login.isCaptivePortal)
        let success = ReachabilityService.captivePortalResult(
            data: Data("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>".utf8),
            response: response(url), requestedURL: url)
        XCTAssertFalse(success.isCaptivePortal)
    }

    func testCancelledProbeReturnsWithoutStartingNetworkWork() async {
        let service = LatencyMeasurementService(timeout: 30)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return await service.measureTCPLatency(to: .cloudflare)
        }
        task.cancel()
        let result = await task.value
        XCTAssertNil(result.rttMs)
        XCTAssertEqual(result.error, "Connection cancelled")
    }

    func testInvalidSampleCountIsRejectedWithoutNetworkWork() async {
        let result = await LatencyMeasurementService().measureAverageLatency(samples: -1)
        XCTAssertNil(result.rttMs)
        XCTAssertNotNil(result.error)
    }

    func testHTTPMeasurementRejectsUnencryptedAndInvalidURLs() async {
        let service = LatencyMeasurementService()
        for url in ["http://example.com", "file:///etc/hosts", "relative/path"] {
            let result = await service.measureHTTPResponseTime(url: url)
            XCTAssertNil(result.rttMs)
            XCTAssertEqual(result.error, "Invalid URL")
        }
    }
}
