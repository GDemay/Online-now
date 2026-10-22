import Foundation
import Network
import SystemConfiguration
import Combine

/// A coherent path snapshot, published after all path properties have been updated.
public struct NetworkPathSnapshot: Equatable, Sendable {
    public let isConnected: Bool
    public let connectionType: ConnectionType
    public let isVPNActive: Bool
    public let isConstrained: Bool
    public let isExpensive: Bool
}

/// Observes network interfaces. Reachability still requires an internet probe.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
@MainActor
public class NetworkMonitor: ObservableObject {
    // A cancelled NWPathMonitor cannot be started again.
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "OnlineNow.NetworkMonitor")
    private var generation = UUID()

    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionType: ConnectionType = .none
    @Published public private(set) var isVPNActive = false
    @Published public private(set) var isConstrained = false
    @Published public private(set) var isExpensive = false
    @Published public private(set) var snapshot: NetworkPathSnapshot?
    public var isMonitoring: Bool { monitor != nil }

    public init() {}

    deinit { monitor?.cancel() }

    /// Idempotent, and safe to call again after stop().
    public func start() {
        guard monitor == nil else { return }
        generation = UUID()
        let currentGeneration = generation
        let newMonitor = NWPathMonitor()
        monitor = newMonitor
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self, self.generation == currentGeneration, self.monitor != nil else { return }
                let connected = path.status == .satisfied
                let type: ConnectionType
                if !connected { type = .none }
                else if path.usesInterfaceType(.wifi) { type = .wifi }
                else if path.usesInterfaceType(.cellular) { type = .cellular }
                else if path.usesInterfaceType(.wiredEthernet) { type = .ethernet }
                else { type = .unknown }

                self.isConnected = connected
                self.connectionType = type
                self.isConstrained = path.isConstrained
                self.isExpensive = path.isExpensive
                self.isVPNActive = connected && self.checkVPNActive()
                self.snapshot = NetworkPathSnapshot(
                    isConnected: connected, connectionType: type,
                    isVPNActive: self.isVPNActive,
                    isConstrained: path.isConstrained, isExpensive: path.isExpensive
                )
            }
        }
        newMonitor.start(queue: queue)
    }

    public func stop() {
        generation = UUID() // Ignore callbacks already queued by the old monitor.
        monitor?.pathUpdateHandler = nil
        monitor?.cancel()
        monitor = nil
    }

    /// Best-effort tunnel detection. iOS does not expose an authoritative VPN status API.
    private func checkVPNActive() -> Bool {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = settings["__SCOPED__"] as? [String: Any] else { return false }
        let prefixes = ["tap", "tun", "ppp", "ipsec", "utun"]
        return scoped.keys.contains { name in
            prefixes.contains { name.lowercased().hasPrefix($0) }
        }
    }

    public var networkSummary: String {
        guard isConnected else { return "Not connected" }
        var result = connectionType.displayName
        if isVPNActive { result += " + Possible VPN" }
        if isConstrained { result += " (Low Data Mode)" }
        return result
    }
}
