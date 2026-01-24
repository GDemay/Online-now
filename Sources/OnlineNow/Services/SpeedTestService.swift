import Foundation

/// Service to measure download speed accurately
/// Uses streaming download with larger files for reliable measurements
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor SpeedTestService {

    /// Test file sizes for different test modes
    /// Quick test: 5MB, Full test: 10MB - needed for accurate high-speed measurements
    private let quickTestBytes = 5_000_000    // 5MB
    private let fullTestBytes = 10_000_000    // 10MB

    /// Minimum test duration for reliable measurement (seconds)
    private let minimumTestDuration: TimeInterval = 1.0

    /// Maximum test duration before we have enough data (seconds)
    private let maximumTestDuration: TimeInterval = 10.0

    /// Timeout for speed tests (seconds)
    private let timeout: TimeInterval = 15

    public init() {}

    /// Performs a speed test and returns the result
    /// Uses streaming download to measure actual throughput accurately
    /// - Parameter quick: If true, uses smaller test file
    /// - Returns: SpeedTestResult with speed in Mbps
    public func measureSpeed(quick: Bool = false) async -> SpeedTestResult {
        let testBytes = quick ? quickTestBytes : fullTestBytes
        let testURL = URL(string: "https://speed.cloudflare.com/__down?bytes=\(testBytes)")!

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        // Disable caching to ensure fresh download
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        do {
            let (bytes, response) = try await session.bytes(from: testURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return SpeedTestResult(
                    speedMbps: nil,
                    bytesDownloaded: 0,
                    durationSeconds: 0,
                    error: "Invalid response from speed test server"
                )
            }

            var totalBytes = 0
            var measurementStartTime: Date?
            var bytesAtMeasurementStart = 0
            let overallStartTime = Date()

            // Stream the data and measure throughput after initial warmup
            for try await _ in bytes {
                totalBytes += 1

                // Skip first 100KB as warmup (connection establishment overhead)
                if totalBytes == 100_000 {
                    measurementStartTime = Date()
                    bytesAtMeasurementStart = totalBytes
                }

                // Check if we've downloaded enough for a reliable measurement
                let elapsed = Date().timeIntervalSince(overallStartTime)
                if elapsed >= maximumTestDuration {
                    break
                }
            }

            let overallElapsed = Date().timeIntervalSince(overallStartTime)

            // Calculate speed from the measurement period (excluding warmup)
            let speedMbps: Double
            let measuredBytes: Int
            let measuredDuration: Double

            if let startTime = measurementStartTime {
                measuredDuration = Date().timeIntervalSince(startTime)
                measuredBytes = totalBytes - bytesAtMeasurementStart

                if measuredDuration >= 0.1 && measuredBytes > 0 {
                    let bitsDownloaded = Double(measuredBytes) * 8
                    speedMbps = bitsDownloaded / measuredDuration / 1_000_000
                } else {
                    // Fallback to overall measurement if warmup didn't complete
                    let bitsDownloaded = Double(totalBytes) * 8
                    speedMbps = bitsDownloaded / overallElapsed / 1_000_000
                }
            } else {
                // No warmup period completed - use overall
                measuredDuration = overallElapsed
                measuredBytes = totalBytes
                let bitsDownloaded = Double(totalBytes) * 8
                speedMbps = bitsDownloaded / overallElapsed / 1_000_000
            }

            return SpeedTestResult(
                speedMbps: speedMbps,
                bytesDownloaded: totalBytes,
                durationSeconds: overallElapsed,
                error: nil
            )

        } catch let error as URLError {
            let errorMessage: String

            switch error.code {
            case .timedOut:
                errorMessage = "Speed test timed out - connection may be very slow"
            case .notConnectedToInternet:
                errorMessage = "No internet connection"
            case .networkConnectionLost:
                errorMessage = "Connection lost during test"
            default:
                errorMessage = "Speed test failed: \(error.localizedDescription)"
            }

            return SpeedTestResult(
                speedMbps: nil,
                bytesDownloaded: 0,
                durationSeconds: 0,
                error: errorMessage
            )

        } catch {
            return SpeedTestResult(
                speedMbps: nil,
                bytesDownloaded: 0,
                durationSeconds: 0,
                error: "Speed test failed: \(error.localizedDescription)"
            )
        }
    }

    /// Returns a human-readable description of the speed
    public static func speedDescription(_ speedMbps: Double) -> String {
        switch speedMbps {
        case 0..<1:
            return "Very Slow"
        case 1..<5:
            return "Slow"
        case 5..<25:
            return "Moderate"
        case 25..<100:
            return "Fast"
        case 100...:
            return "Very Fast"
        default:
            return "Unknown"
        }
    }

    /// Returns a confidence message based on speed test conditions
    public static func confidenceMessage(_ result: SpeedTestResult) -> String {
        guard result.speedMbps != nil else {
            return "Unable to measure speed"
        }

        if result.durationSeconds < 0.5 {
            return "Quick test - actual speed may vary"
        } else if result.durationSeconds > 10 {
            return "Slow connection detected"
        } else {
            return "Reliable measurement"
        }
    }
}

/// Result of a speed test
public struct SpeedTestResult: Sendable {
    /// Download speed in Megabits per second (nil if test failed)
    public let speedMbps: Double?

    /// Total bytes downloaded during the test
    public let bytesDownloaded: Int

    /// Duration of the test in seconds
    public let durationSeconds: Double

    /// Error message if test failed
    public let error: String?

    /// Formatted speed string
    public var formattedSpeed: String {
        guard let speed = speedMbps else { return "—" }
        if speed < 1 {
            return String(format: "%.2f Mbps", speed)
        } else if speed < 10 {
            return String(format: "%.1f Mbps", speed)
        } else {
            return String(format: "%.0f Mbps", speed)
        }
    }

    /// Data used in human-readable format
    public var dataUsed: String {
        if bytesDownloaded < 1024 {
            return "\(bytesDownloaded) B"
        } else if bytesDownloaded < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytesDownloaded) / 1024)
        } else {
            return String(format: "%.2f MB", Double(bytesDownloaded) / 1024 / 1024)
        }
    }

    public init(speedMbps: Double?, bytesDownloaded: Int, durationSeconds: Double, error: String?) {
        self.speedMbps = speedMbps
        self.bytesDownloaded = bytesDownloaded
        self.durationSeconds = durationSeconds
        self.error = error
    }
}
