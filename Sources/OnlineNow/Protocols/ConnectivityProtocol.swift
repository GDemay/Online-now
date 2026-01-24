import Combine
import Foundation

/// Represents the verified connectivity status
public enum ConnectivityStatus: Sendable, Equatable {
    /// Device is fully connected with verified internet access
    case connected

    /// Device has local network access but internet is not verified
    case localOnly

    /// Device appears connected but is behind a captive portal
    case captivePortal

    /// Device has no network connectivity
    case disconnected

    /// Connectivity status is being determined
    case checking

    /// Human-readable description
    public var description: String {
        switch self {
        case .connected: return "Connected"
        case .localOnly: return "Local Only"
        case .captivePortal: return "Captive Portal"
        case .disconnected: return "Disconnected"
        case .checking: return "Checking..."
        }
    }

    /// Whether internet is actually reachable
    public var hasInternet: Bool {
        self == .connected
    }

    /// Whether there is any form of network connection
    public var hasLocalNetwork: Bool {
        switch self {
        case .connected, .localOnly, .captivePortal:
            return true
        case .disconnected, .checking:
            return false
        }
    }
}

/// Network metadata providing detailed connection information
public struct NetworkMetadata: Sendable, Equatable {
    /// Type of network interface
    public let connectionType: ConnectionType

    /// Whether the connection is expensive (cellular/hotspot)
    public let isExpensive: Bool

    /// Whether Low Data Mode is enabled
    public let isConstrained: Bool

    /// Whether a VPN/Proxy tunnel is active
    public let isUsingTunnel: Bool

    /// Current latency in milliseconds (if measured)
    public let latencyMs: Double?

    /// Measured download speed in Mbps (if measured)
    public let speedMbps: Double?

    /// Signal quality assessment
    public let signalQuality: SignalQuality

    public init(
        connectionType: ConnectionType = .none,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        isUsingTunnel: Bool = false,
        latencyMs: Double? = nil,
        speedMbps: Double? = nil,
        signalQuality: SignalQuality = .unknown
    ) {
        self.connectionType = connectionType
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.isUsingTunnel = isUsingTunnel
        self.latencyMs = latencyMs
        self.speedMbps = speedMbps
        self.signalQuality = signalQuality
    }

    /// Default empty metadata
    public static let empty = NetworkMetadata()
}

/// Signal quality assessment
public enum SignalQuality: String, Sendable, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unknown = "Unknown"

    /// Color name for UI representation
    public var colorName: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }
}

/// Protocol defining the core connectivity monitoring interface
/// Enables dependency injection and mocking for tests
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public protocol ConnectivityProviding: ObservableObject {
    /// Current connectivity status
    var status: ConnectivityStatus { get }

    /// Detailed network metadata
    var metadata: NetworkMetadata { get }

    /// Publisher for status changes
    var statusPublisher: AnyPublisher<ConnectivityStatus, Never> { get }

    /// Publisher for metadata changes
    var metadataPublisher: AnyPublisher<NetworkMetadata, Never> { get }

    /// Start monitoring connectivity
    func startMonitoring()

    /// Stop monitoring connectivity
    func stopMonitoring()

    /// Force a connectivity check
    func checkNow() async -> ConnectivityStatus
}
