import Foundation
import SwiftData

/// Represents a single connectivity check record stored locally
@available(iOS 17.0, *)
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

    /// Latency in milliseconds (nil if not measured)
    public var latencyMs: Double?

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
        latencyMs: Double? = nil,
        isVPNActive: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.isReachable = isReachable
        self.speedMbps = speedMbps
        self.latencyMs = latencyMs
        self.isVPNActive = isVPNActive
        self.errorMessage = errorMessage
    }
}

/// Connection type enumeration for type safety
public enum ConnectionType: String, Codable, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
    case none = "None"

    public var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .unknown: return "questionmark.circle"
        case .none: return "wifi.slash"
        }
    }

    public var displayName: String {
        return rawValue
    }
}
