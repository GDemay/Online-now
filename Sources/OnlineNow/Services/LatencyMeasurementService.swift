import Foundation
import Network

/// Measures TCP connection setup time. Hostname endpoints include DNS resolution;
/// even IP endpoints include local scheduling and are an estimate of network RTT.
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
        self.timeout = timeout.isFinite ? min(30, max(0.1, timeout)) : 3
    }

    /// Measures TCP connection setup time with a deadline and cancellation support.
    public func measureTCPLatency(to endpoint: LatencyEndpoint) async -> LatencyResult {
        guard !Task.isCancelled else {
            return LatencyResult(rttMs: nil, method: .tcp, endpoint: endpoint.displayName,
                                 error: "Connection cancelled")
        }
        let probe = TCPConnectionProbe(endpoint: endpoint, timeout: timeout)
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                probe.start(continuation)
            }
        }, onCancel: { probe.cancel() })
    }

    /// Measures average latency across multiple endpoints for more reliable results
    /// - Parameter count: Number of measurements to take
    /// - Returns: Average latency result
    public func measureAverageLatency(samples count: Int = 3) async -> LatencyResult {
        guard count > 0 else {
            return LatencyResult(rttMs: nil, method: .tcp, endpoint: "Multiple endpoints",
                                 error: "At least one sample is required")
        }
        let endpoints: [LatencyEndpoint] = [.cloudflare, .googleDNS, .google]
        var successfulMeasurements: [Double] = []
        var errors: [String] = []

        // Take multiple measurements
        for _ in 0..<min(count, 10) {
            guard !Task.isCancelled else {
                return LatencyResult(rttMs: nil, method: .tcp, endpoint: "Multiple endpoints",
                                     error: "Measurement cancelled")
            }
            // Rotate through endpoints
            for endpoint in endpoints {
                guard !Task.isCancelled else { break }
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
        guard !Task.isCancelled else {
            return LatencyResult(rttMs: nil, method: .http, endpoint: urlString,
                                 error: "Measurement cancelled")
        }
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https", url.host != nil else {
            return LatencyResult(
                rttMs: nil,
                method: .http,
                endpoint: urlString,
                error: "Invalid URL"
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            let startTime = ProcessInfo.processInfo.systemUptime
            let (_, response) = try await session.data(for: request)
            let elapsed = (ProcessInfo.processInfo.systemUptime - startTime) * 1000
            guard !Task.isCancelled else {
                return LatencyResult(rttMs: nil, method: .http, endpoint: url.host ?? urlString,
                                     error: "Measurement cancelled")
            }

            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                response.url?.host == url.host
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

/// All NWConnection callbacks, deadline, and cancellation are serialized on this
/// queue. Completion clears the continuation before cancelling the connection,
/// preventing a second resume from the subsequent `.cancelled` callback.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
private final class TCPConnectionProbe: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.gdemay.onlinenow.tcp-probe")
    private let connection: NWConnection
    private let endpoint: LatencyMeasurementService.LatencyEndpoint
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<LatencyResult, Never>?
    private var deadline: DispatchWorkItem?
    private var cancelled = false
    private var startTime: TimeInterval = 0

    init(endpoint: LatencyMeasurementService.LatencyEndpoint, timeout: TimeInterval) {
        self.endpoint = endpoint
        self.timeout = timeout
        self.connection = NWConnection(host: NWEndpoint.Host(endpoint.rawValue),
                                       port: NWEndpoint.Port(rawValue: endpoint.port)!, using: .tcp)
    }

    func start(_ continuation: CheckedContinuation<LatencyResult, Never>) {
        queue.async {
            self.continuation = continuation
            guard !self.cancelled else { self.finish(error: "Connection cancelled"); return }
            self.startTime = ProcessInfo.processInfo.systemUptime
            self.connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready: self.finish(error: nil)
                case .failed(let error): self.finish(error: "Connection failed: \(error.localizedDescription)")
                case .cancelled: self.finish(error: "Connection cancelled")
                default: break
                }
            }
            let deadline = DispatchWorkItem { [weak self] in
                self?.finish(error: "Connection timed out")
            }
            self.deadline = deadline
            self.queue.asyncAfter(deadline: .now() + self.timeout, execute: deadline)
            self.connection.start(queue: self.queue)
        }
    }

    func cancel() {
        queue.async {
            self.cancelled = true
            self.finish(error: "Connection cancelled")
        }
    }

    private func finish(error: String?) {
        guard let continuation = continuation else { return }
        self.continuation = nil
        deadline?.cancel()
        deadline = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        let elapsed = (ProcessInfo.processInfo.systemUptime - startTime) * 1000
        continuation.resume(returning: LatencyResult(rttMs: error == nil ? elapsed : nil,
                                                     method: .tcp, endpoint: endpoint.displayName,
                                                     error: error))
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
        guard let rtt = rttMs, rtt.isFinite, rtt >= 0 else { return "Unknown" }

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
        guard let rtt = rttMs, rtt.isFinite, rtt >= 0 else { return "—" }
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
