import Foundation
import SwiftData

/// Represents a single connectivity check record stored locally
/// Note: Requires iOS 17+ for SwiftData @Model. Core SDK works on iOS 15+.
@available(iOS 17.0, macOS 14.0, *)
@Model
public final class ConnectivityCheck {
    /// Unique identifier for the check
    public var id: UUID

    /// When the check was performed
    public var timestamp: Date

    /// Whether the device was connected to the internet
    public var isConnected: Bool

    /// Type of connection (wifi, cellular, ethernet, unknown)
    public var connectionType: String

    /// Whether real internet was reachable (not just network present)
    public var isReachable: Bool

    /// Measured download speed in Mbps (nil if not measured)
    public var speedMbps: Double?

    /// True network latency (TCP RTT) in milliseconds (nil if not measured)
    public var rttMs: Double?

    /// HTTP response time in milliseconds (nil if not measured)
    /// Includes DNS, TCP, TLS, and server processing time
    public var responseTimeMs: Double?

    /// Legacy latency property (for backward compatibility)
    /// Note: In newer versions, use rttMs for network latency or responseTimeMs for HTTP timing
    @available(
        *, deprecated, message: "Use rttMs for network latency or responseTimeMs for HTTP timing"
    )
    public var latencyMs: Double?

    /// Method used for latency measurement (e.g., "TCP", "HTTP")
    public var measurementMethod: String?

    /// Whether a VPN was active during the check
    public var isVPNActive: Bool

    /// Any error message if the check failed
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        isConnected: Bool,
        connectionType: String,
        isReachable: Bool,
        speedMbps: Double? = nil,
        rttMs: Double? = nil,
        responseTimeMs: Double? = nil,
        latencyMs: Double? = nil,
        measurementMethod: String? = nil,
        isVPNActive: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.isReachable = isReachable
        self.speedMbps = speedMbps
        self.rttMs = rttMs
        self.responseTimeMs = responseTimeMs
        self.latencyMs = latencyMs ?? rttMs  // Fallback to rttMs for backward compatibility
        self.measurementMethod = measurementMethod
        self.isVPNActive = isVPNActive
        self.errorMessage = errorMessage
    }
}
