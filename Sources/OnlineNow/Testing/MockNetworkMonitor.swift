import Foundation
import Combine
import SwiftUI

/// Mock network monitor for testing and SwiftUI previews
/// Allows simulation of various network states without real connectivity
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public final class MockNetworkMonitor: ObservableObject, ConnectivityProviding {

    // MARK: - Published Properties

    @Published public private(set) var status: ConnectivityStatus
    @Published public private(set) var metadata: NetworkMetadata

    // MARK: - Publishers

    public var statusPublisher: AnyPublisher<ConnectivityStatus, Never> {
        $status.eraseToAnyPublisher()
    }

    public var metadataPublisher: AnyPublisher<NetworkMetadata, Never> {
        $metadata.eraseToAnyPublisher()
    }

    // MARK: - Simulation State

    private var simulationTask: Task<Void, Never>?
    private var isSimulating = false

    // MARK: - Preset Scenarios

    /// Predefined network scenarios for common test cases
    public enum Scenario: CaseIterable {
        case connected
        case disconnected
        case captivePortal
        case slowConnection
        case unstable
        case cellularExpensive
        case vpnActive
        case lowDataMode

        public var description: String {
            switch self {
            case .connected: return "Connected (WiFi)"
            case .disconnected: return "Disconnected"
            case .captivePortal: return "Captive Portal (Hotel WiFi)"
            case .slowConnection: return "Slow Connection"
            case .unstable: return "Unstable Connection"
            case .cellularExpensive: return "Cellular (Expensive)"
            case .vpnActive: return "VPN Active"
            case .lowDataMode: return "Low Data Mode"
            }
        }
    }

    // MARK: - Initialization

    public init(
        initialStatus: ConnectivityStatus = .connected,
        metadata: NetworkMetadata = .init(
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false,
            isUsingTunnel: false,
            latencyMs: 25,
            speedMbps: 100,
            signalQuality: .excellent
        )
    ) {
        self.status = initialStatus
        self.metadata = metadata
    }

    /// Create a mock with a preset scenario
    public convenience init(scenario: Scenario) {
        switch scenario {
        case .connected:
            self.init(
                initialStatus: .connected,
                metadata: .init(
                    connectionType: .wifi,
                    isExpensive: false,
                    isConstrained: false,
                    isUsingTunnel: false,
                    latencyMs: 25,
                    speedMbps: 100,
                    signalQuality: .excellent
                )
            )

        case .disconnected:
            self.init(
                initialStatus: .disconnected,
                metadata: .init(connectionType: .none, signalQuality: .unknown)
            )

        case .captivePortal:
            self.init(
                initialStatus: .captivePortal,
                metadata: .init(
                    connectionType: .wifi,
                    isExpensive: false,
                    isConstrained: false,
                    isUsingTunnel: false,
                    latencyMs: nil,
                    speedMbps: nil,
                    signalQuality: .unknown
                )
            )

        case .slowConnection:
            self.init(
                initialStatus: .connected,
                metadata: .init(
                    connectionType: .wifi,
                    isExpensive: false,
                    isConstrained: false,
                    isUsingTunnel: false,
                    latencyMs: 250,
                    speedMbps: 2,
                    signalQuality: .poor
                )
            )

        case .unstable:
            self.init(
                initialStatus: .connected,
                metadata: .init(
                    connectionType: .wifi,
                    isExpensive: false,
                    isConstrained: false,
                    isUsingTunnel: false,
                    latencyMs: 150,
                    speedMbps: 10,
                    signalQuality: .fair
                )
            )

        case .cellularExpensive:
            self.init(
                initialStatus: .connected,
                metadata: .init(
                    connectionType: .cellular,
                    isExpensive: true,
                    isConstrained: false,
                    isUsingTunnel: false,
                    latencyMs: 80,
                    speedMbps: 25,
                    signalQuality: .good
                )
            )

        case .vpnActive:
            self.init(
                initialStatus: .connected,
                metadata: .init(
                    connectionType: .wifi,
                    isExpensive: false,
                    isConstrained: false,
                    isUsingTunnel: true,
                    latencyMs: 45,
                    speedMbps: 50,
                    signalQuality: .good
                )
            )

        case .lowDataMode:
            self.init(
                initialStatus: .connected,
                metadata: .init(
                    connectionType: .cellular,
                    isExpensive: true,
                    isConstrained: true,
                    isUsingTunnel: false,
                    latencyMs: 60,
                    speedMbps: 5,
                    signalQuality: .fair
                )
            )
        }
    }

    // MARK: - ConnectivityProviding Protocol

    public func startMonitoring() {
        // Mock implementation - no-op for testing
    }

    public func stopMonitoring() {
        stopSimulation()
    }

    public func checkNow() async -> ConnectivityStatus {
        return status
    }

    // MARK: - Simulation Methods

    /// Set the current status
    public func setStatus(_ newStatus: ConnectivityStatus) {
        status = newStatus
    }

    /// Set the current metadata
    public func setMetadata(_ newMetadata: NetworkMetadata) {
        metadata = newMetadata
    }

    /// Apply a preset scenario
    public func apply(scenario: Scenario) {
        let mock = MockNetworkMonitor(scenario: scenario)
        self.status = mock.status
        self.metadata = mock.metadata
    }

    /// Simulate a connection drop and recovery
    /// - Parameters:
    ///   - dropDuration: How long the connection is down
    ///   - recovery: Optional status to recover to (defaults to connected)
    public func simulateConnectionDrop(
        dropDuration: TimeInterval = 3.0,
        recovery: ConnectivityStatus = .connected
    ) {
        let previousStatus = status
        let previousMetadata = metadata

        // Drop connection
        status = .disconnected
        metadata = NetworkMetadata(connectionType: .none, signalQuality: .unknown)

        simulationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(dropDuration * 1_000_000_000))

            guard !Task.isCancelled else { return }

            self.status = recovery
            if recovery == previousStatus {
                self.metadata = previousMetadata
            } else {
                self.metadata = NetworkMetadata(
                    connectionType: .wifi,
                    signalQuality: .good
                )
            }
        }
    }

    /// Simulate unstable connection with random drops
    /// - Parameters:
    ///   - dropProbability: Probability of a drop per interval (0-1)
    ///   - checkInterval: How often to check for drops
    public func simulateUnstableConnection(
        dropProbability: Double = 0.3,
        checkInterval: TimeInterval = 2.0
    ) {
        isSimulating = true

        simulationTask = Task { @MainActor in
            while !Task.isCancelled && self.isSimulating {
                if Double.random(in: 0...1) < dropProbability {
                    // Simulate brief drop
                    self.status = .disconnected
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    self.status = .connected
                }

                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }

    /// Simulate captive portal scenario
    public func simulateCaptivePortal() {
        status = .captivePortal
        metadata = NetworkMetadata(
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false,
            isUsingTunnel: false,
            latencyMs: nil,
            speedMbps: nil,
            signalQuality: .unknown
        )
    }

    /// Simulate captive portal resolution (user logged in)
    public func resolveCaptivePortal() {
        status = .connected
        metadata = NetworkMetadata(
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false,
            isUsingTunnel: false,
            latencyMs: 30,
            speedMbps: 50,
            signalQuality: .good
        )
    }

    /// Stop any running simulation
    public func stopSimulation() {
        isSimulating = false
        simulationTask?.cancel()
        simulationTask = nil
    }

    /// Simulate gradual degradation of connection quality
    public func simulateDegradation(duration: TimeInterval = 10.0) {
        let steps = 5
        let stepDuration = duration / Double(steps)

        simulationTask = Task { @MainActor in
            let qualities: [SignalQuality] = [.excellent, .good, .fair, .poor, .unknown]
            let speeds: [Double] = [100, 50, 20, 5, 1]
            let latencies: [Double] = [20, 50, 100, 200, 500]

            for i in 0..<steps {
                guard !Task.isCancelled else { return }

                self.metadata = NetworkMetadata(
                    connectionType: self.metadata.connectionType,
                    isExpensive: self.metadata.isExpensive,
                    isConstrained: self.metadata.isConstrained,
                    isUsingTunnel: self.metadata.isUsingTunnel,
                    latencyMs: latencies[i],
                    speedMbps: speeds[i],
                    signalQuality: qualities[i]
                )

                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }

            // Finally disconnect
            self.status = .disconnected
        }
    }
}

// MARK: - Preview Helpers

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public extension MockNetworkMonitor {
    /// Create mocks for all scenarios
    static var allScenarios: [MockNetworkMonitor] {
        Scenario.allCases.map { MockNetworkMonitor(scenario: $0) }
    }

    /// Connected mock for previews
    static var connected: MockNetworkMonitor {
        MockNetworkMonitor(scenario: .connected)
    }

    /// Disconnected mock for previews
    static var disconnected: MockNetworkMonitor {
        MockNetworkMonitor(scenario: .disconnected)
    }

    /// Captive portal mock for previews
    static var captivePortal: MockNetworkMonitor {
        MockNetworkMonitor(scenario: .captivePortal)
    }

    /// Slow connection mock for previews
    static var slow: MockNetworkMonitor {
        MockNetworkMonitor(scenario: .slowConnection)
    }
}

// MARK: - SwiftUI Environment Key

@available(iOS 15.0, macOS 12.0, *)
private struct MockNetworkMonitorKey: EnvironmentKey {
    static let defaultValue: MockNetworkMonitor? = nil
}

@available(iOS 15.0, macOS 12.0, *)
public extension EnvironmentValues {
    var mockNetworkMonitor: MockNetworkMonitor? {
        get { self[MockNetworkMonitorKey.self] }
        set { self[MockNetworkMonitorKey.self] = newValue }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public extension View {
    /// Inject a mock network monitor for previews and testing
    func mockNetwork(_ monitor: MockNetworkMonitor) -> some View {
        environment(\.mockNetworkMonitor, monitor)
    }

    /// Inject a mock network scenario for previews
    func mockNetworkScenario(_ scenario: MockNetworkMonitor.Scenario) -> some View {
        environment(\.mockNetworkMonitor, MockNetworkMonitor(scenario: scenario))
    }
}
