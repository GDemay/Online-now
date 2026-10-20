import Foundation

/// Measures end-to-end HTTPS download throughput. Connection setup is included;
/// this is a useful estimate for this server, not a guaranteed ISP line rate.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor SpeedTestService {
    private let timeout: TimeInterval = 15

    public init() {}

    /// Downloads up to 5 MB (quick) or 10 MB (full), only when requested by the user.
    /// The response is written to disk so the entire test file is not held in memory.
    public func measureSpeed(quick: Bool = false) async -> SpeedTestResult {
        guard !Task.isCancelled else { return failure("Speed test cancelled") }
        let expectedBytes = quick ? 5_000_000 : 10_000_000
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(expectedBytes)")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        // Compression would measure compressed wire bytes against decoded file size.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let start = ProcessInfo.processInfo.systemUptime
        do {
            let (fileURL, response) = try await session.download(for: request)
            defer { try? FileManager.default.removeItem(at: fileURL) }
            guard !Task.isCancelled else { return failure("Speed test cancelled") }
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            let bytes = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return Self.result(bytes: bytes, duration: elapsed, expectedBytes: expectedBytes,
                               response: response)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                return failure("Speed test cancelled")
            }
            let message: String
            switch (error as? URLError)?.code {
            case .timedOut: message = "Speed test timed out. Try again on a faster connection."
            case .notConnectedToInternet: message = "No internet connection"
            case .networkConnectionLost: message = "Connection lost during test"
            default: message = "Speed test failed: \(error.localizedDescription)"
            }
            return failure(message)
        }
    }

    /// Validate the actual transfer before calculating a result. A portal/error page,
    /// compressed response, or incomplete file must never become a successful test.
    static func result(bytes: Int, duration: Double, expectedBytes: Int,
                       response: URLResponse) -> SpeedTestResult {
        let http = response as? HTTPURLResponse
        let encoding = http?.value(forHTTPHeaderField: "Content-Encoding")?.lowercased()
        guard http?.statusCode == 200,
              response.url?.host == "speed.cloudflare.com",
              response.mimeType?.lowercased() != "text/html",
              encoding == nil || encoding == "identity",
              expectedBytes > 0, bytes == expectedBytes,
              duration.isFinite, duration > 0 else {
            return SpeedTestResult(speedMbps: nil, bytesDownloaded: max(0, bytes),
                                   durationSeconds: max(0, duration.isFinite ? duration : 0),
                                   error: "The speed test server returned an incomplete or unexpected response.")
        }
        return SpeedTestResult(speedMbps: Double(bytes) * 8 / duration / 1_000_000,
                               bytesDownloaded: bytes, durationSeconds: duration, error: nil)
    }

    private func failure(_ message: String) -> SpeedTestResult {
        SpeedTestResult(speedMbps: nil, bytesDownloaded: 0, durationSeconds: 0, error: message)
    }

    public static func speedDescription(_ speedMbps: Double) -> String {
        guard speedMbps.isFinite, speedMbps >= 0 else { return "Unknown" }
        switch speedMbps {
        case ..<1: return "Very Slow"
        case ..<5: return "Slow"
        case ..<25: return "Moderate"
        case ..<100: return "Fast"
        default: return "Very Fast"
        }
    }

    public static func confidenceMessage(_ result: SpeedTestResult) -> String {
        guard let speed = result.speedMbps, speed.isFinite, speed >= 0,
              result.error == nil else { return "Unable to measure speed" }
        if result.durationSeconds < 0.5 { return "Short sample — actual speed may vary" }
        return "HTTPS download estimate — speeds vary by server and network"
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
        guard let speed = speedMbps, speed.isFinite, speed >= 0 else { return "—" }
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
