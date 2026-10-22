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

/// Verifies an uncached, expected response from independent HTTPS providers.
/// Redirects and login pages are not evidence of internet access.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor ReachabilityService: ReachabilityChecking {
    private let maxRetries: Int
    private let detectCaptivePortals: Bool
    private let session: URLSession

    public init(timeout: TimeInterval = 5, maxRetries: Int = 1,
                detectCaptivePortals: Bool = true) {
        self.maxRetries = min(3, max(1, maxRetries))
        self.detectCaptivePortals = detectCaptivePortals
        let configuration = Self.configuration(timeout: timeout)
        session = URLSession(configuration: configuration, delegate: ConnectivityRedirectDelegate(), delegateQueue: nil)
    }

    /// Test seam for deterministic URLProtocol responses; never used by production.
    init(configuration: URLSessionConfiguration, maxRetries: Int = 1,
         detectCaptivePortals: Bool = true) {
        self.maxRetries = min(3, max(1, maxRetries))
        self.detectCaptivePortals = detectCaptivePortals
        session = URLSession(configuration: configuration, delegate: ConnectivityRedirectDelegate(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    /// Checks a known provider without treating a redirect or login page as success.
    /// Uses the same bounded, uncached session as the primary connectivity check.
    func checkEndpoint(_ url: URL) async -> Bool {
        guard !Task.isCancelled, Self.isKnownInternetEndpoint(url) else { return false }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled else { return false }
            return Self.isExpectedInternetResponse(data: data, response: response, for: url)
        } catch {
            return false
        }
    }

    public func checkReachability() async -> ReachabilityResult {
        let start = ProcessInfo.processInfo.systemUptime
        let endpoints = [
            URL(string: "https://www.google.com/generate_204")!,
            URL(string: "https://cloudflare.com/cdn-cgi/trace")!,
            URL(string: "https://www.apple.com/library/test/success.html")!
        ]
        for url in endpoints {
            for attempt in 0..<maxRetries {
                guard !Task.isCancelled else { return cancelledResult() }
                let checkStart = ProcessInfo.processInfo.systemUptime
                do {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                    let (data, response) = try await session.data(for: request)
                    guard !Task.isCancelled else { return cancelledResult() }
                    if Self.isExpectedInternetResponse(data: data, response: response, for: url) {
                        return ReachabilityResult(isReachable: true,
                            responseTimeMs: (ProcessInfo.processInfo.systemUptime - checkStart) * 1000,
                            error: nil)
                    }
                } catch {
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                        return cancelledResult()
                    }
                }
                if attempt + 1 < maxRetries {
                    do { try await Task.sleep(nanoseconds: 200_000_000) }
                    catch { return cancelledResult() }
                }
            }
        }
        return ReachabilityResult(isReachable: false,
            responseTimeMs: (ProcessInfo.processInfo.systemUptime - start) * 1000,
            error: "Unable to reach internet")
    }

    public func detectCaptivePortal() async -> CaptivePortalResult {
        guard detectCaptivePortals else { return .noCaptivePortal }
        guard !Task.isCancelled else {
            return CaptivePortalResult(isCaptivePortal: false, error: "Check cancelled")
        }
        let url = URL(string: "http://captive.apple.com/hotspot-detect.html")!
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled else {
                return CaptivePortalResult(isCaptivePortal: false, error: "Check cancelled")
            }
            return Self.captivePortalResult(data: data, response: response, requestedURL: url)
        } catch {
            return CaptivePortalResult(isCaptivePortal: false, error: error.localizedDescription)
        }
    }

    /// HTTPS reachability takes priority; a broken HTTP probe alone cannot mark a
    /// working connection offline. Only investigate portals if HTTPS probes fail.
    public func checkConnectivity() async -> (
        reachability: ReachabilityResult, captivePortal: CaptivePortalResult
    ) {
        let reachability = await checkReachability()
        guard !reachability.isReachable, !Task.isCancelled else {
            return (reachability, .noCaptivePortal)
        }
        return (reachability, await detectCaptivePortal())
    }

    static func isExpectedInternetResponse(data: Data, response: URLResponse, for url: URL) -> Bool {
        guard isKnownInternetEndpoint(url), let http = response as? HTTPURLResponse,
              http.url?.scheme == "https", http.url?.host == url.host,
              http.url?.path == url.path else { return false }
        switch url.host {
        case "www.google.com":
            return http.statusCode == 204 && data.isEmpty
        case "cloudflare.com":
            guard http.statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else { return false }
            let lines = body.split(separator: "\n")
            return lines.contains { $0.hasPrefix("ip=") } && lines.contains { $0.hasPrefix("h=") }
        case "www.apple.com":
            return http.statusCode == 200 && isAppleSuccess(data)
        default:
            return false
        }
    }

    private static func isKnownInternetEndpoint(_ url: URL) -> Bool {
        guard url.scheme == "https", url.port == nil || url.port == 443,
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return false }
        switch (url.host, url.path) {
        case ("www.google.com", "/generate_204"),
             ("cloudflare.com", "/cdn-cgi/trace"),
             ("www.apple.com", "/library/test/success.html"):
            return true
        default:
            return false
        }
    }

    static func captivePortalResult(data: Data, response: URLResponse,
                                    requestedURL: URL) -> CaptivePortalResult {
        guard let http = response as? HTTPURLResponse else {
            return CaptivePortalResult(isCaptivePortal: false, error: "Invalid response")
        }
        if (300...399).contains(http.statusCode) {
            let destination = http.value(forHTTPHeaderField: "Location")
                .flatMap { URL(string: $0, relativeTo: requestedURL)?.absoluteURL }
            let safeURL = destination.flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
            return CaptivePortalResult(isCaptivePortal: true, portalURL: safeURL)
        }
        if http.statusCode == 200 {
            return isAppleSuccess(data) ? .noCaptivePortal :
                CaptivePortalResult(isCaptivePortal: true, portalURL: http.url)
        }
        if http.statusCode == 511 {
            return CaptivePortalResult(isCaptivePortal: true, portalURL: http.url)
        }
        return CaptivePortalResult(isCaptivePortal: false,
                                   error: "Captive portal check was inconclusive (HTTP \(http.statusCode))")
    }

    private static func isAppleSuccess(_ data: Data) -> Bool {
        guard let body = String(data: data, encoding: .utf8)?.lowercased() else { return false }
        return body.contains("<title>success</title>") && body.contains("<body>success</body>")
    }

    private static func configuration(timeout: TimeInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        let boundedTimeout = timeout.isFinite ? min(30, max(0.1, timeout)) : 5
        config.timeoutIntervalForRequest = boundedTimeout
        config.timeoutIntervalForResource = boundedTimeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return config
    }

    private func cancelledResult() -> ReachabilityResult {
        ReachabilityResult(isReachable: false, responseTimeMs: 0, error: "Check cancelled")
    }
}

/// Following a captive-portal redirect can turn its login page into an apparent
/// successful internet response. Return the original redirect to the caller.
private final class ConnectivityRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Result of a reachability check
public struct ReachabilityResult: Sendable {
    /// Whether the internet is reachable
    public let isReachable: Bool

    /// HTTP response time in milliseconds (includes DNS, TCP, TLS, server processing)
    /// Note: This is NOT pure network latency - use LatencyMeasurementService for RTT
    public let responseTimeMs: Double

    /// Error message if check failed
    public let error: String?

    /// Legacy property for backward compatibility
    @available(
        *, deprecated,
        message:
            "Use responseTimeMs instead - this measures HTTP response time, not pure network latency"
    )
    public var latencyMs: Double {
        return responseTimeMs
    }

    public init(isReachable: Bool, responseTimeMs: Double, error: String?) {
        self.isReachable = isReachable
        self.responseTimeMs = responseTimeMs
        self.error = error
    }

    /// Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init with responseTimeMs parameter")
    public init(isReachable: Bool, latencyMs: Double, error: String?) {
        self.isReachable = isReachable
        self.responseTimeMs = latencyMs
        self.error = error
    }
}
