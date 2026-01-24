import Foundation

/// Service to verify actual internet reachability via HTTP ping
/// Uses multiple reliable endpoints for verification
@available(iOS 17.0, *)
public actor ReachabilityService {

    /// Primary URL - Google's connectivity check (very reliable, returns 204)
    private let primaryURL = URL(string: "https://www.google.com/generate_204")!

    /// Fallback URL - Apple's captive portal detection
    private let fallbackURL = URL(string: "https://captive.apple.com/hotspot-detect.html")!

    /// Third fallback - Cloudflare
    private let tertiaryURL = URL(string: "https://cloudflare.com/cdn-cgi/trace")!

    /// Timeout for reachability checks (seconds) - shorter for faster feedback
    private let timeout: TimeInterval = 5

    /// Maximum retry attempts
    private let maxRetries = 1

    public init() {}

    /// Verifies if the internet is actually reachable
    /// - Returns: ReachabilityResult with status and latency
    public func checkReachability() async -> ReachabilityResult {
        let startTime = Date()

        // Try primary URL first (Google - most reliable)
        if let result = await performCheck(url: primaryURL, startTime: startTime, expectedStatus: 204) {
            return result
        }

        // Try fallback URL (Apple)
        if let result = await performCheck(url: fallbackURL, startTime: startTime, expectedStatus: nil) {
            return result
        }

        // Try tertiary URL (Cloudflare)
        if let result = await performCheck(url: tertiaryURL, startTime: startTime, expectedStatus: nil) {
            return result
        }

        // All attempts failed
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        return ReachabilityResult(
            isReachable: false,
            latencyMs: elapsed,
            error: "Unable to reach internet"
        )
    }

    private func performCheck(url: URL, startTime: Date, expectedStatus: Int?) async -> ReachabilityResult? {
        for attempt in 0..<maxRetries {
            do {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = timeout
                config.timeoutIntervalForResource = timeout
                config.waitsForConnectivity = false

                let session = URLSession(configuration: config)
                defer { session.invalidateAndCancel() }

                let checkStart = Date()
                let (_, response) = try await session.data(from: url)

                if let httpResponse = response as? HTTPURLResponse {
                    // Check for expected status or any success status
                    let isSuccess: Bool
                    if let expected = expectedStatus {
                        isSuccess = httpResponse.statusCode == expected
                    } else {
                        isSuccess = (200...399).contains(httpResponse.statusCode)
                    }

                    if isSuccess {
                        let latency = Date().timeIntervalSince(checkStart) * 1000
                        return ReachabilityResult(
                            isReachable: true,
                            latencyMs: latency,
                            error: nil
                        )
                    }
                }
            } catch {
                // Brief delay before retry
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                }
            }
        }

        return nil
    }
}

/// Result of a reachability check
public struct ReachabilityResult: Sendable {
    /// Whether the internet is reachable
    public let isReachable: Bool

    /// Latency in milliseconds
    public let latencyMs: Double

    /// Error message if check failed
    public let error: String?

    public init(isReachable: Bool, latencyMs: Double, error: String?) {
        self.isReachable = isReachable
        self.latencyMs = latencyMs
        self.error = error
    }
}
