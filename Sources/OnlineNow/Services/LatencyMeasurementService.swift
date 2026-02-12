import Foundation
import Network

/// Service for measuring true network latency (RTT) using TCP connection timing
/// Provides accurate network latency measurements excluding HTTP/DNS overhead
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor LatencyMeasurementService {

    /// Common endpoints for latency testing
    public enum LatencyEndpoint: String, CaseIterable {
        case cloudflare = "1.1.1.1"
        case googleDNS = "8.8.8.8"
        case apple = "www.apple.com"
        case google = "www.google.com"

        public var port: UInt16 {
            switch self {
            case .cloudflare, .googleDNS:
                return 443  // HTTPS port
            case .apple, .google:
                return 443
            }
        }

        public var displayName: String {
            switch self {
            case .cloudflare:
                return "Cloudflare DNS"
            case .googleDNS:
                return "Google DNS"
            case .apple:
                return "Apple"
            case .google:
                return "Google"
            }
        }
    }

    /// Timeout for latency measurements (seconds)
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 3.0) {
        self.timeout = timeout
    }

    /// Measures TCP connection latency to the specified endpoint
    /// This measures pure network RTT by timing TCP SYN -> SYN-ACK handshake
    /// - Parameters:
    ///   - endpoint: The endpoint to measure latency to
    /// - Returns: LatencyResult with RTT measurement
    public func measureTCPLatency(to endpoint: LatencyEndpoint) async -> LatencyResult {
        let host = NWEndpoint.Host(endpoint.rawValue)
        let port = NWEndpoint.Port(rawValue: endpoint.port)!

        let connection = NWConnection(
            host: host,
            port: port,
            using: .tcp
        )

        let startTime = Date()
        var connectionEstablished = false
        var error: String?

        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Connection established - measure latency
                    let elapsed = Date().timeIntervalSince(startTime) * 1000
                    connectionEstablished = true
                    connection.cancel()

                    continuation.resume(
                        returning: LatencyResult(
                            rttMs: elapsed,
                            method: .tcp,
                            endpoint: endpoint.displayName,
                            error: nil
                        ))

                case .failed(let err):
                    connection.cancel()
                    if !connectionEstablished {
                        continuation.resume(
                            returning: LatencyResult(
                                rttMs: nil,
                                method: .tcp,
                                endpoint: endpoint.displayName,
                                error: "Connection failed: \(err.localizedDescription)"
                            ))
                    }

                case .cancelled:
                    if !connectionEstablished {
                        connection.cancel()
                        continuation.resume(
                            returning: LatencyResult(
                                rttMs: nil,
                                method: .tcp,
                                endpoint: endpoint.displayName,
                                error: "Connection cancelled"
                            ))
                    }

                case .waiting(let err):
                    // Timeout handling
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                        if !connectionEstablished {
                            connection.cancel()
                            continuation.resume(
                                returning: LatencyResult(
                                    rttMs: nil,
                                    method: .tcp,
                                    endpoint: endpoint.displayName,
                                    error: "Connection timeout: \(err.localizedDescription)"
                                ))
                        }
                    }

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    /// Measures average latency across multiple endpoints for more reliable results
    /// - Parameter count: Number of measurements to take
    /// - Returns: Average latency result
    public func measureAverageLatency(samples count: Int = 3) async -> LatencyResult {
        let endpoints: [LatencyEndpoint] = [.cloudflare, .googleDNS, .google]
        var successfulMeasurements: [Double] = []
        var errors: [String] = []

        // Take multiple measurements
        for _ in 0..<count {
            // Rotate through endpoints
            for endpoint in endpoints {
                let result = await measureTCPLatency(to: endpoint)
                if let rtt = result.rttMs {
                    successfulMeasurements.append(rtt)
                    break  // Got a successful measurement, move to next sample
                } else if let err = result.error {
                    errors.append(err)
                }
            }
        }

        // Calculate average and return result
        if successfulMeasurements.isEmpty {
            return LatencyResult(
                rttMs: nil,
                method: .tcp,
                endpoint: "Multiple endpoints",
                error: errors.first ?? "All measurements failed"
            )
        }

        let average = successfulMeasurements.reduce(0, +) / Double(successfulMeasurements.count)
        return LatencyResult(
            rttMs: average,
            method: .tcp,
            endpoint: "Average of \(successfulMeasurements.count) samples",
            error: nil
        )
    }

    /// Measures HTTP response time (for comparison with TCP latency)
    /// This includes DNS lookup, TCP handshake, TLS handshake, and server processing
    /// - Parameter urlString: URL to test
    /// - Returns: LatencyResult with full HTTP response time
    public func measureHTTPResponseTime(url urlString: String) async -> LatencyResult {
        guard let url = URL(string: urlString) else {
            return LatencyResult(
                rttMs: nil,
                method: .http,
                endpoint: urlString,
                error: "Invalid URL"
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            let startTime = Date()
            let (_, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime) * 1000

            guard let httpResponse = response as? HTTPURLResponse,
                (200...399).contains(httpResponse.statusCode)
            else {
                return LatencyResult(
                    rttMs: nil,
                    method: .http,
                    endpoint: url.host ?? urlString,
                    error: "Invalid response"
                )
            }

            return LatencyResult(
                rttMs: elapsed,
                method: .http,
                endpoint: url.host ?? urlString,
                error: nil
            )

        } catch {
            return LatencyResult(
                rttMs: nil,
                method: .http,
                endpoint: url.host ?? urlString,
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Result Types

/// Result of a latency measurement
public struct LatencyResult: Sendable {
    /// Round-trip time in milliseconds (nil if measurement failed)
    public let rttMs: Double?

    /// Measurement method used
    public let method: LatencyMethod

    /// Endpoint that was tested
    public let endpoint: String

    /// Error message if measurement failed
    public let error: String?

    /// Quality description based on latency
    public var qualityDescription: String {
        guard let rtt = rttMs else { return "Unknown" }

        switch rtt {
        case 0..<20:
            return "Excellent"
        case 20..<50:
            return "Very Good"
        case 50..<100:
            return "Good"
        case 100..<200:
            return "Fair"
        case 200..<500:
            return "Poor"
        default:
            return "Very Poor"
        }
    }

    /// Formatted latency string
    public var formattedLatency: String {
        guard let rtt = rttMs else { return "—" }
        return String(format: "%.0f ms", rtt)
    }

    public init(rttMs: Double?, method: LatencyMethod, endpoint: String, error: String?) {
        self.rttMs = rttMs
        self.method = method
        self.endpoint = endpoint
        self.error = error
    }
}

/// Method used for latency measurement
public enum LatencyMethod: String, Sendable {
    case tcp = "TCP"
    case http = "HTTP"
    case icmp = "ICMP"

    public var description: String {
        switch self {
        case .tcp:
            return "TCP handshake timing"
        case .http:
            return "HTTP request timing"
        case .icmp:
            return "ICMP echo (ping)"
        }
    }
}
