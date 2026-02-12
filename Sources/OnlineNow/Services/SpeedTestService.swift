import Foundation

/// Service to measure download speed accurately
/// Uses streaming download with larger files for reliable measurements
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor SpeedTestService {

    /// Test file sizes for different test modes
    /// Quick test: 5MB, Full test: 10MB - needed for accurate high-speed measurements
    private let quickTestBytes = 5_000_000  // 5MB
    private let fullTestBytes = 10_000_000  // 10MB

    /// Minimum test duration for reliable measurement (seconds)
    private let minimumTestDuration: TimeInterval = 1.0

    /// Maximum test duration before we have enough data (seconds)
    private let maximumTestDuration: TimeInterval = 10.0

    /// Timeout for speed tests (seconds)
    private let timeout: TimeInterval = 15

    public init() {}

    /// Performs a speed test and returns the result
    /// Uses download with progress tracking to measure actual throughput accurately
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
            let overallStartTime = Date()
            let (data, response) = try await session.data(from: testURL)

            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                return SpeedTestResult(
                    speedMbps: nil,
                    bytesDownloaded: 0,
                    durationSeconds: 0,
                    error: "Invalid response from speed test server"
                )
            }

            let overallElapsed = Date().timeIntervalSince(overallStartTime)
            let totalBytes = data.count

            // Apply warmup adjustment: exclude first 100KB from speed calculation
            // This accounts for TCP slow start and connection establishment overhead
            let warmupThreshold = 100_000  // 100KB
            let measuredBytes: Int
            let measuredDuration: Double

            if totalBytes > warmupThreshold && overallElapsed > 0.5 {
                // Estimate warmup time proportionally (conservative estimate)
                // Typically first 100KB takes disproportionately longer
                let warmupRatio = Double(warmupThreshold) / Double(totalBytes)
                let estimatedWarmupTime = overallElapsed * warmupRatio * 2.0  // 2x factor for slow start

                measuredBytes = totalBytes - warmupThreshold
                measuredDuration = max(overallElapsed - estimatedWarmupTime, overallElapsed * 0.8)
            } else {
                // Download was too small or too fast - use overall measurement
                measuredBytes = totalBytes
                measuredDuration = overallElapsed
            }
            // Calculate speed in Mbps: (bits / duration) / 1,000,000
            let bitsDownloaded = Double(measuredBytes) * 8
            let speedMbps = bitsDownloaded / measuredDuration / 1_000_000
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
