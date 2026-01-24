import Foundation
import Network
import SystemConfiguration
import Combine

/// A monitor that observes network connectivity status in real-time
/// Supports iOS 15+, macOS 12+, watchOS 8+
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    /// Whether the device has network connectivity
    @Published public private(set) var isConnected: Bool = false

    /// Current connection type (uses OnlineNow's unified ConnectionType)
    @Published public private(set) var connectionType: ConnectionType = .unknown

    /// Whether a VPN is currently active
    @Published public private(set) var isVPNActive: Bool = false

    /// Whether the connection is constrained (e.g., Low Data Mode)
    @Published public private(set) var isConstrained: Bool = false

    /// Whether the connection is expensive (cellular or personal hotspot)
    @Published public private(set) var isExpensive: Bool = false

    /// Current network path for detailed inspection
    private var currentPath: NWPath?

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.currentPath = path
                self?.isConnected = path.status == .satisfied
                self?.isConstrained = path.isConstrained
                self?.isExpensive = path.isExpensive
                self?.updateConnectionType(path)
                self?.updateVPNStatus()
            }
        }
    }

    /// Starts monitoring network connectivity
    public func start() {
        monitor.start(queue: queue)
    }

    /// Stops monitoring network connectivity
    public func stop() {
        monitor.cancel()
    }

    private func updateConnectionType(_ path: NWPath) {
        // If not connected at all (airplane mode, no network), report as none
        if path.status != .satisfied {
            connectionType = .unknown
            return
        }

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }

    /// Detects if a VPN is currently active by checking network interfaces
    private func updateVPNStatus() {
        isVPNActive = checkVPNActive()
    }

    /// Checks for active VPN by examining network interfaces
    private func checkVPNActive() -> Bool {
        // Check for VPN interface types in the current path
        if let path = currentPath {
            // VPNs typically use "other" interface type
            if path.usesInterfaceType(.other) {
                return true
            }
        }

        // Additional check using network interfaces
        guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = cfDict["__SCOPED__"] as? [String: Any] else {
            return false
        }

        // Look for common VPN interface names
        let vpnInterfacePatterns = ["tap", "tun", "ppp", "ipsec", "utun"]
        for key in scoped.keys {
            for pattern in vpnInterfacePatterns {
                if key.lowercased().contains(pattern) {
                    return true
                }
            }
        }

        return false
    }

    /// Returns a summary of the current network state
    public var networkSummary: String {
        guard isConnected else { return "Not connected" }

        var summary = connectionType.rawValue

        if isVPNActive {
            summary += " + VPN"
        }

        if isConstrained {
            summary += " (Low Data Mode)"
        }

        return summary
    }
}
