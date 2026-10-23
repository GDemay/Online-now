import Combine
import Foundation
import Network
import SwiftUI

/// Unified view model for managing all connectivity-related state
/// Note: Requires iOS 17+ for SwiftData integration
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class ConnectivityViewModel: ObservableObject {

    // MARK: - Screenshot/Preview Mode

    /// Enable preview mode for taking screenshots (shake device or triple-tap to toggle)
    @Published public var isPreviewMode: Bool = false

    /// Simulated state for preview mode
    @Published public var previewState: AppState = .online

    /// Toggle between preview states for screenshots
    public func cyclePreviewState() {
        #if DEBUG
        let states: [AppState] = [
            .online, .offline, .limitedConnectivity, .checking, .measuringSpeed,
        ]
        if let currentIndex = states.firstIndex(of: previewState) {
            let nextIndex = (currentIndex + 1) % states.count
            previewState = states[nextIndex]
        } else {
            previewState = .online
        }

        // Update displayed values based on preview state
        if isPreviewMode {
            applyPreviewState()
        }
        #endif
    }

    /// Apply preview state values for screenshots
    #if DEBUG
    private func applyPreviewState() {
        switch previewState {
        case .online:
            state = .online
            isConnected = true
            isReachable = true
            connectionType = .wifi
            rttMs = 15
            responseTimeMs = 23
            latencyMs = 15  // For backward compatibility
            speedResult = SpeedTestResult(
                speedMbps: 156.8, bytesDownloaded: 19_660_800, durationSeconds: 1.0, error: nil)
            signalQuality = "Excellent"
            isVPNActive = false
            errorMessage = nil
        case .offline:
            state = .offline
            isConnected = false
            isReachable = false
            connectionType = .none
            rttMs = nil
            responseTimeMs = nil
            latencyMs = nil
            speedResult = nil
            signalQuality = "Offline"
            isVPNActive = false
            errorMessage = nil
        case .limitedConnectivity:
            state = .limitedConnectivity
            isConnected = true
            isReachable = false
            connectionType = .wifi
            rttMs = 320
            responseTimeMs = 450
            latencyMs = 320
            speedResult = SpeedTestResult(
                speedMbps: 2.1, bytesDownloaded: 262_144, durationSeconds: 1.0, error: nil)
            signalQuality = "Poor"
            isVPNActive = false
            errorMessage = "Internet unreachable"
        case .checking:
            state = .checking
            isConnected = true
            connectionType = .wifi
        case .measuringSpeed:
            state = .measuringSpeed
            isConnected = true
            isReachable = true
            connectionType = .wifi
        default:
            break
        }
    }

    #endif

    /// Toggle preview mode on/off
    public func togglePreviewMode() {
        #if DEBUG
        isPreviewMode.toggle()
        if isPreviewMode {
            // Stop real monitoring
            stopMonitoring()
            applyPreviewState()
            print("📸 PREVIEW MODE ON - Tap screen to cycle states, shake to exit")
        } else {
            // Resume real monitoring
            startMonitoring()
            print("📸 PREVIEW MODE OFF - Resuming real network monitoring")
        }
        #endif
    }

    // MARK: - Published State

    /// Current app state
    @Published public private(set) var state: AppState = .idle

    /// Whether the device has network connectivity
    @Published public private(set) var isConnected: Bool = false

    /// Whether internet is actually reachable
    @Published public private(set) var isReachable: Bool = false

    /// Current connection type
    @Published public private(set) var connectionType: ConnectionType = .none

    /// Whether VPN is active
    @Published public private(set) var isVPNActive: Bool = false

    /// Latest speed test result
    @Published public private(set) var speedResult: SpeedTestResult?

    /// TCP connection setup estimate in milliseconds; includes local scheduling overhead.
    @Published public private(set) var rttMs: Double?

    /// HTTP response time (includes DNS, TCP, TLS, server processing)
    @Published public private(set) var responseTimeMs: Double?

    /// Legacy latency property for backward compatibility
    @available(
        *, deprecated,
        message: "Use rttMs for network latency or responseTimeMs for full HTTP timing"
    )
    @Published public private(set) var latencyMs: Double?

    /// Error message if any
    @Published public private(set) var errorMessage: String?

    /// Whether Google is reachable
    @Published public private(set) var isGoogleReachable: Bool = false

    /// Whether Cloudflare DNS is reachable
    @Published public private(set) var isCloudflareReachable: Bool = false

    /// Last check timestamp
    @Published public private(set) var lastCheckTime: Date?

    /// Signal strength description
    @Published public private(set) var signalQuality: String = "Unknown"

    /// Diagnostic mode - enables validation against system tools
    @Published public var isDiagnosticMode: Bool = false

    /// Latest diagnostic results
    @Published public private(set) var diagnosticResults: [DiagnosticResult] = []

    // MARK: - Services and operation lifetime

    private let networkMonitor: NetworkMonitor
    private let diagnosticService: DiagnosticService
    public let historyManager: HistoryManager
    public let tippingManager: TippingManager

    // Internal closures allow deterministic lifecycle tests without live network traffic.
    var reachabilityCheck: @MainActor () async -> ReachabilityResult
    var latencyMeasurement: @MainActor () async -> LatencyResult
    var speedMeasurement: @MainActor () async -> SpeedTestResult
    var endpointCheck: @MainActor (String) async -> Bool

    private var reachabilityTimer: Timer?
    private var checkTask: Task<Void, Never>?
    private var operationID = UUID()
    private var usesOfflineFixture = false
    @Published public private(set) var isMonitoring = false
    @Published public private(set) var isPerformingCheck = false
    @Published public private(set) var isPerformingSpeedTest = false
    @Published public private(set) var isConstrained = false
    @Published public private(set) var isExpensive = false
    private var cancellables = Set<Combine.AnyCancellable>()

    public convenience init(purchasesEnabled: Bool = true, tipPromptsEnabled: Bool = true) {
        self.init(networkMonitor: NetworkMonitor(),
                  purchasesEnabled: purchasesEnabled, tipPromptsEnabled: tipPromptsEnabled)
    }

    init(networkMonitor: NetworkMonitor, tippingManager: TippingManager? = nil,
         purchasesEnabled: Bool = true, tipPromptsEnabled: Bool = true) {
        self.networkMonitor = networkMonitor
        diagnosticService = DiagnosticService()
        historyManager = HistoryManager()
        self.tippingManager = tippingManager ?? TippingManager(
            purchasesEnabled: purchasesEnabled, tipPromptsEnabled: tipPromptsEnabled)
        let reachability = ReachabilityService()
        let latency = LatencyMeasurementService()
        let speed = SpeedTestService()
        reachabilityCheck = { await reachability.checkReachability() }
        latencyMeasurement = { await latency.measureTCPLatency(to: .cloudflare) }
        speedMeasurement = { await speed.measureSpeed(quick: false) }
        endpointCheck = { urlString in
            guard let url = URL(string: urlString) else { return false }
            return await reachability.checkEndpoint(url)
        }
        #if DEBUG
        usesOfflineFixture = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            && ProcessInfo.processInfo.arguments.contains("--offline")
        #endif
        setupNetworkMonitorObservation()
        historyManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        self.tippingManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    deinit {
        reachabilityTimer?.invalidate()
        checkTask?.cancel()
    }

    /// Monitoring runs only while the screen is active. Speed tests are always explicit.
    public func startMonitoring() {
        guard !isMonitoring, !isPreviewMode else { return }
        isMonitoring = true
        state = .checking
        if usesOfflineFixture {
            applyNetworkSnapshot(NetworkPathSnapshot(
                isConnected: false, connectionType: .none, isVPNActive: false,
                isConstrained: false, isExpensive: false
            ))
            return
        }
        networkMonitor.start()
        reachabilityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring, self.isConnected else { return }
                await self.performCheck()
            }
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        networkMonitor.stop()
        reachabilityTimer?.invalidate()
        reachabilityTimer = nil
        cancelCurrentCheck()
        updateState()
    }

    private func cancelCurrentCheck() {
        operationID = UUID()
        checkTask?.cancel()
        checkTask = nil
        isPerformingCheck = false
        isPerformingSpeedTest = false
    }

    // MARK: - Diagnostic Methods

    /// Runs comprehensive diagnostics and compares with system tools
    /// - Note: macOS only for full diagnostics (uses system ping)
    public func runDiagnostics() async {
        guard isDiagnosticMode else { return }

        print("🔬 Running diagnostics...")
        let results = await diagnosticService.runFullDiagnostics()
        diagnosticResults = results

        print("📊 Diagnostic Results:")
        for result in results {
            print(result.summary)
        }
    }

    /// Validates latency against system ping
    public func validateLatency() async -> DiagnosticResult {
        return await diagnosticService.validateLatency()
    }

    /// Validates speed test measurements
    public func validateSpeedTest() async -> DiagnosticResult {
        return await diagnosticService.validateSpeedTest()
    }

    /// Describe measured connection quality without inventing scores for missing measurements.
    private func updateSignalQuality() {
        guard isReachable else {
            signalQuality = isConnected ? "Unavailable" : "Offline"
            return
        }
        var scores: [Int] = []
        if let rtt = rttMs, rtt.isFinite, rtt >= 0 {
            switch rtt {
            case 0..<20: scores.append(4)
            case 20..<50: scores.append(3)
            case 50..<100: scores.append(2)
            case 100..<200: scores.append(1)
            default: scores.append(0)
            }
        }
        if let result = speedResult, result.error == nil, let speed = result.speedMbps,
           speed.isFinite, speed >= 0 {
            switch speed {
            case 50...: scores.append(4)
            case 25..<50: scores.append(3)
            case 10..<25: scores.append(2)
            case 5..<10: scores.append(1)
            default: scores.append(0)
            }
        }
        guard !scores.isEmpty else { signalQuality = "Unknown"; return }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        switch average {
        case 3.5...: signalQuality = "Excellent"
        case 2.5..<3.5: signalQuality = "Good"
        case 1.5..<2.5: signalQuality = "Fair"
        default: signalQuality = "Poor"
        }
    }

    /// Performs one serialized check. Results from an old network or stopped screen are discarded.
    public func performCheck(includeSpeedTest: Bool = false) async {
        guard !Task.isCancelled, !isPreviewMode, !isPerformingCheck else { return }
        guard isConnected else {
            clearMeasurements()
            // An explicit offline refresh is still a useful diagnostic sample.
            // Timers and initial offline snapshots do not call this path.
            historyManager.recordCheck(isConnected: false, connectionType: .none, isReachable: false)
            lastCheckTime = Date()
            updateState()
            return
        }
        let id = UUID()
        operationID = id
        isPerformingCheck = true
        state = .checking
        errorMessage = nil
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.runCheck(id: id, includeSpeedTest: includeSpeedTest)
        }
        checkTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func runCheck(id: UUID, includeSpeedTest: Bool) async {
        defer {
            if operationID == id {
                isPerformingCheck = false
                isPerformingSpeedTest = false
                checkTask = nil
                updateState()
            }
        }
        let reachability = await reachabilityCheck()
        guard canApply(id) else { return }
        isReachable = reachability.isReachable
        responseTimeMs = reachability.isReachable ? reachability.responseTimeMs : nil
        lastCheckTime = Date()
        errorMessage = reachability.error
        rttMs = nil
        latencyMs = nil

        if isReachable {
            async let measuredLatency = latencyMeasurement()
            async let google = endpointCheck("https://www.google.com/generate_204")
            async let cloudflare = endpointCheck("https://cloudflare.com/cdn-cgi/trace")
            let (latency, googleReachable, cloudflareReachable) = await (measuredLatency, google, cloudflare)
            guard canApply(id) else { return }
            rttMs = latency.rttMs
            latencyMs = latency.rttMs ?? responseTimeMs
            isGoogleReachable = googleReachable
            isCloudflareReachable = cloudflareReachable
        } else {
            isGoogleReachable = false
            isCloudflareReachable = false
            speedResult = nil
        }

        // Speed measurements consume data and never run on a timer or network transition.
        var measuredSpeed: Double?
        if includeSpeedTest, isReachable {
            isPerformingSpeedTest = true
            state = .measuringSpeed
            let result = await speedMeasurement()
            guard canApply(id) else { return }
            speedResult = result
            errorMessage = result.error
            if result.error == nil, let speed = result.speedMbps, speed.isFinite, speed >= 0 {
                measuredSpeed = speed
                tippingManager.recordSpeedTestCompleted()
            }
        }
        guard canApply(id) else { return }
        historyManager.recordCheck(
            isConnected: isConnected, connectionType: connectionType, isReachable: isReachable,
            speedMbps: measuredSpeed, rttMs: rttMs, responseTimeMs: responseTimeMs,
            isVPNActive: isVPNActive, errorMessage: errorMessage
        )
        updateSignalQuality()
        // Resolve the final state before VoiceOver announces it.
        isPerformingCheck = false
        isPerformingSpeedTest = false
        updateState()
        if includeSpeedTest { announceStatusChange() }
    }

    private func canApply(_ id: UUID) -> Bool {
        !Task.isCancelled && operationID == id && isConnected && !isPreviewMode
    }

    public func quickCheck() async { await performCheck() }
    public func fullCheck() async { await performCheck(includeSpeedTest: true) }

    private func setupNetworkMonitorObservation() {
        networkMonitor.$snapshot.compactMap { $0 }.sink { [weak self] snapshot in
            self?.applyNetworkSnapshot(snapshot)
        }.store(in: &cancellables)
    }

    // Kept internal so tests can simulate airplane-mode and interface changes deterministically.
    func applyNetworkSnapshot(_ snapshot: NetworkPathSnapshot, automaticallyCheck: Bool = true) {
        guard isMonitoring, !isPreviewMode else { return }
        cancelCurrentCheck()
        let wasConnected = isConnected
        isConnected = snapshot.isConnected
        connectionType = snapshot.connectionType
        isVPNActive = snapshot.isVPNActive
        isConstrained = snapshot.isConstrained
        isExpensive = snapshot.isExpensive
        clearMeasurements()
        updateState()
        if isConnected && automaticallyCheck {
            checkTask = Task<Void, Never> { [weak self] in
                guard let self else { return }
                await self.performCheck()
            }
        } else if !isConnected && wasConnected {
            historyManager.recordCheck(isConnected: false, connectionType: .none, isReachable: false)
            lastCheckTime = Date()
        }
    }

    private func clearMeasurements() {
        isReachable = false
        isGoogleReachable = false
        isCloudflareReachable = false
        rttMs = nil
        responseTimeMs = nil
        latencyMs = nil
        speedResult = nil
        errorMessage = nil
        signalQuality = isConnected ? "Unknown" : "Offline"
    }

    private func updateState() {
        if !isConnected { state = .offline; signalQuality = "Offline" }
        else if isPerformingSpeedTest { state = .measuringSpeed }
        else if isPerformingCheck { state = .checking }
        else { state = isReachable ? .online : .limitedConnectivity }
    }

    private func announceStatusChange() {
        var announcement: String
        switch state {
        case .online:
            announcement = "Connected to internet via \(connectionType.displayName)"
            if let result = speedResult, result.error == nil, let speed = result.speedMbps,
               speed.isFinite, speed >= 0 {
                let speedDesc = SpeedTestService.speedDescription(speed)
                announcement += ". Speed: \(speedDesc)"
            }
        case .offline:
            announcement = "No internet connection"
        case .limitedConnectivity:
            announcement = "Limited connectivity. Network connected but internet not reachable"
        default:
            return
        }

        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

// MARK: - App State

public enum AppState: Equatable {
    case idle
    case checking
    case online
    case offline
    case limitedConnectivity
    case measuringSpeed
    case error(String)

    public var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .checking:
            return "Checking..."
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        case .limitedConnectivity:
            return "Limited"
        case .measuringSpeed:
            return "Measuring Speed..."
        case .error(let message):
            return message
        }
    }

    public var icon: String {
        switch self {
        case .idle:
            return "circle"
        case .checking, .measuringSpeed:
            return "arrow.triangle.2.circlepath"
        case .online:
            return "wifi"
        case .offline:
            return "wifi.slash"
        case .limitedConnectivity:
            return "wifi.exclamationmark"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    public var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .checking, .measuringSpeed:
            return .blue
        case .online:
            return .green
        case .offline:
            return .red
        case .limitedConnectivity:
            return .orange
        case .error:
            return .red
        }
    }
}
