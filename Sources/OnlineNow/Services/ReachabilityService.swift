import Foundation

// MARK: - Reachability Types

/// Protocol for reachability verification service
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public protocol ReachabilityChecking: Sendable {
    /// Check if internet is reachable
    func checkReachability() async -> ReachabilityResult

    /// Check for captive portal
    func detectCaptivePortal() async -> CaptivePortalResult
}

/// Result of captive portal detection
public struct CaptivePortalResult: Sendable {
    /// Whether a captive portal was detected
    public let isCaptivePortal: Bool

    /// URL of the captive portal login page (if detected)
    public let portalURL: URL?

    /// Error message if detection failed
    public let error: String?

    public init(isCaptivePortal: Bool, portalURL: URL? = nil, error: String? = nil) {
        self.isCaptivePortal = isCaptivePortal
        self.portalURL = portalURL
        self.error = error
    }

    /// Not a captive portal
    public static let noCaptivePortal = CaptivePortalResult(isCaptivePortal: false)
}

// MARK: - Reachability Service

/// Enhanced service to verify actual internet reachability and detect captive portals
/// Uses multiple reliable endpoints for verification with fallback mechanisms
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor ReachabilityService: ReachabilityChecking {

    // MARK: - Captive Portal Detection Endpoints

    /// Apple's captive portal detection endpoint
    /// Returns specific text "Success" when not behind a captive portal
    private let appleCaptiveURL = URL(string: "http://captive.apple.com/hotspot-detect.html")!
    private let appleExpectedResponse = "Success"

    // MARK: - Internet Reachability Endpoints

    /// Primary URL - Google's connectivity check (very reliable, returns 204)
    private let primaryURL = URL(string: "https://www.google.com/generate_204")!

    /// Fallback URL - Cloudflare trace
    private let fallbackURL = URL(string: "https://cloudflare.com/cdn-cgi/trace")!

    /// Third fallback - Apple's secure endpoint
    private let tertiaryURL = URL(string: "https://www.apple.com/library/test/success.html")!

    // MARK: - Configuration

    /// Timeout for reachability checks (seconds)
    private let timeout: TimeInterval

    /// Maximum retry attempts per endpoint
    private let maxRetries: Int

    /// Whether to perform captive portal detection
    private let detectCaptivePortals: Bool

    // MARK: - Initialization

    public init(
        timeout: TimeInterval = 5,
        maxRetries: Int = 1,
        detectCaptivePortals: Bool = true
    ) {
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.detectCaptivePortals = detectCaptivePortals
    }

    // MARK: - ReachabilityChecking Protocol

    /// Verifies if the internet is actually reachable
    /// - Returns: ReachabilityResult with status and latency
    public func checkReachability() async -> ReachabilityResult {
        let startTime = Date()

        // Try primary URL first (Google - most reliable, 204 response)
        if let result = await performCheck(
            url: primaryURL, startTime: startTime, expectedStatus: 204)
        {
            return result
        }

        // Try fallback URL (Cloudflare)
        if let result = await performCheck(
            url: fallbackURL, startTime: startTime, expectedStatus: nil)
        {
            return result
        }

        // Try tertiary URL (Apple)
        if let result = await performCheck(
            url: tertiaryURL, startTime: startTime, expectedStatus: nil)
        {
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

    /// Detects if the device is behind a captive portal
    /// Uses Apple's captive portal detection endpoint which returns specific content
    /// - Returns: CaptivePortalResult indicating captive portal status
    public func detectCaptivePortal() async -> CaptivePortalResult {
        guard detectCaptivePortals else {
            return .noCaptivePortal
        }

        let config = createSessionConfig()
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        do {
            // Use HTTP endpoint - captive portals typically redirect HTTP requests
            var request = URLRequest(url: appleCaptiveURL)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return CaptivePortalResult(isCaptivePortal: false, error: "Invalid response")
            }

            // Check for redirect (common captive portal behavior)
            if (300...399).contains(httpResponse.statusCode) {
                let portalURL = httpResponse.url
                return CaptivePortalResult(
                    isCaptivePortal: true,
                    portalURL: portalURL,
                    error: nil
                )
            }

            // Check if response content matches expected
            if httpResponse.statusCode == 200 {
                let responseString = String(data: data, encoding: .utf8) ?? ""

                // Apple's endpoint returns HTML containing "Success"
                if responseString.contains(appleExpectedResponse) {
                    return .noCaptivePortal
                } else {
                    // Got 200 but different content - likely captive portal injection
                    return CaptivePortalResult(
                        isCaptivePortal: true,
                        portalURL: httpResponse.url,
                        error: nil
                    )
                }
            }

            // Any other status code - inconclusive but likely not captive portal
            return .noCaptivePortal

        } catch let error as URLError {
            return CaptivePortalResult(
                isCaptivePortal: false,
                error: error.localizedDescription
            )
        } catch {
            return CaptivePortalResult(
                isCaptivePortal: false,
                error: error.localizedDescription
            )
        }
    }

    /// Performs comprehensive connectivity check including captive portal detection
    /// - Returns: Tuple of reachability result and captive portal result
    public func checkConnectivity() async -> (
        reachability: ReachabilityResult, captivePortal: CaptivePortalResult
    ) {
        // First check for captive portal (faster, uses HTTP)
        let captiveResult = await detectCaptivePortal()

        // If behind captive portal, internet is not truly reachable
        if captiveResult.isCaptivePortal {
            return (
                ReachabilityResult(
                    isReachable: false, latencyMs: 0, error: "Behind captive portal"),
                captiveResult
            )
        }

        // Check actual internet reachability
        let reachabilityResult = await checkReachability()

        return (reachabilityResult, captiveResult)
    }

    // MARK: - Private Methods

    private func createSessionConfig() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return config
    }

    private func performCheck(url: URL, startTime: Date, expectedStatus: Int?) async
        -> ReachabilityResult?
    {
        for attempt in 0..<maxRetries {
            do {
                let config = createSessionConfig()
                let session = URLSession(configuration: config)
                defer { session.invalidateAndCancel() }

                let checkStart = Date()

                // Use HEAD request for faster checks when possible
                var request = URLRequest(url: url)
                request.httpMethod = expectedStatus == 204 ? "GET" : "HEAD"

                let (_, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
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
                    try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2s
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
