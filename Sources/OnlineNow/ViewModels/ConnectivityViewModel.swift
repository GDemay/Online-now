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
    }

    /// Apply preview state values for screenshots
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
            signalQuality = "No Signal"
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

    /// Toggle preview mode on/off
    public func togglePreviewMode() {
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

    /// True network latency (RTT) from TCP measurement
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

    // MARK: - Services

    private let networkMonitor: NetworkMonitor
    private let reachabilityService: ReachabilityService
    private let speedTestService: SpeedTestService
    private let latencyService: LatencyMeasurementService
    private let diagnosticService: DiagnosticService
    public let historyManager: HistoryManager
    public let tippingManager: TippingManager

    // MARK: - Timers

    private var reachabilityTimer: Timer?
    private var speedTestTimer: Timer?
    private var isPerformingCheck: Bool = false
    private var isPerformingSpeedTest: Bool = false

    // MARK: - Initialization

    public init() {
        self.networkMonitor = NetworkMonitor()
        self.reachabilityService = ReachabilityService()
        self.speedTestService = SpeedTestService()
        self.latencyService = LatencyMeasurementService()
        self.diagnosticService = DiagnosticService()
        self.historyManager = HistoryManager()
        self.tippingManager = TippingManager()

        setupNetworkMonitorObservation()
    }

    // MARK: - Public Methods

    /// Starts monitoring network connectivity with real-time checks
    public func startMonitoring() {
        networkMonitor.start()
        startRealtimeChecks()
    }

    /// Stops monitoring network connectivity
    public func stopMonitoring() {
        networkMonitor.stop()
        stopRealtimeChecks()
    }

    /// Start real-time connectivity and speed checks
    private func startRealtimeChecks() {
        // Initial check
        Task {
            await performRealtimeCheck()
        }

        // Reachability check every 10 seconds (reduced frequency to save data)
        reachabilityTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performRealtimeCheck()
            }
        }

        // Speed test every 2 minutes (reduced frequency to save data - uses ~10KB per test)
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performBackgroundSpeedTest()
            }
        }

        // Run initial speed test after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await performBackgroundSpeedTest()
        }
    }

    /// Stop real-time checks
    private func stopRealtimeChecks() {
        reachabilityTimer?.invalidate()
        reachabilityTimer = nil
        speedTestTimer?.invalidate()
        speedTestTimer = nil
    }

    /// Performs a lightweight reachability check (no speed test)
    private func performRealtimeCheck() async {
        guard !isPerformingCheck else { return }
        isPerformingCheck = true
        defer { isPerformingCheck = false }

        // Debug: Log network monitor state
        print("🔍 NetworkMonitor state - isConnected: \(isConnected), type: \(connectionType)")

        // Only check if network monitor says we're connected
        guard isConnected else {
            isReachable = false
            isGoogleReachable = false
            isCloudflareReachable = false
            signalQuality = "No Signal"
            updateState()
            return
        }

        // Check main reachability
        print("🌐 Performing reachability check...")
        let reachabilityResult = await reachabilityService.checkReachability()
        print(
            "✅ Reachability result: \(reachabilityResult.isReachable), response time: \(reachabilityResult.responseTimeMs)ms, error: \(reachabilityResult.error ?? "none")"
        )

        isReachable = reachabilityResult.isReachable
        responseTimeMs = reachabilityResult.responseTimeMs
        latencyMs = reachabilityResult.responseTimeMs  // For backward compatibility
        lastCheckTime = Date()

        // Measure true network latency (RTT) using TCP
        let latencyResult = await latencyService.measureTCPLatency(to: .cloudflare)
        rttMs = latencyResult.rttMs
        print("📡 TCP latency: \(latencyResult.formattedLatency) to \(latencyResult.endpoint)")

        // If reachability check failed but network is connected, log error
        if !reachabilityResult.isReachable {
            errorMessage = reachabilityResult.error
        }

        // Only check additional endpoints if main reachability succeeded
        if isReachable {
            // Check Google reachability (lightweight HEAD request would be better but this works)
            isGoogleReachable = await checkEndpointReachable(
                urlString: "https://www.google.com/generate_204")

            // Check Cloudflare reachability - using their DNS check endpoint
            isCloudflareReachable = await checkEndpointReachable(
                urlString: "https://cloudflare.com/cdn-cgi/trace")
        } else {
            isGoogleReachable = false
            isCloudflareReachable = false
        }

        // Update signal quality based on latency
        updateSignalQuality()

        // Update state based on reachability
        updateState()
    }

    /// Performs a background speed test without blocking UI
    private func performBackgroundSpeedTest() async {
        guard isReachable && !isPerformingSpeedTest else { return }
        isPerformingSpeedTest = true
        defer { isPerformingSpeedTest = false }

        let speedTestResult = await speedTestService.measureSpeed(quick: true)
        speedResult = speedTestResult

        if let error = speedTestResult.error {
            errorMessage = error
        }

        // Record the check
        historyManager.recordCheck(
            isConnected: isConnected,
            connectionType: connectionType,
            isReachable: isReachable,
            speedMbps: speedResult?.speedMbps,
            latencyMs: rttMs ?? responseTimeMs,  // Use RTT if available, otherwise response time
            isVPNActive: isVPNActive,
            errorMessage: errorMessage
        )

        // Trigger tip prompt after speed test (if appropriate)
        if speedTestResult.error == nil {
            tippingManager.recordSpeedTestCompleted()
        }

        // Update signal quality
        updateSignalQuality()
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

    /// Check if a specific endpoint is reachable
    private func checkEndpointReachable(urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        config.waitsForConnectivity = false

        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    /// Update signal quality based on latency and speed
    /// Uses a more generous algorithm that reflects real-world usage
    private func updateSignalQuality() {
        guard isReachable else {
            signalQuality = "No Signal"
            return
        }

        // Calculate latency score (0-4 points) using true network RTT
        // More generous thresholds - most connections have 20-100ms latency
        let latencyScore: Int
        if let rtt = rttMs {
            switch rtt {
            case 0..<20: latencyScore = 4  // Excellent
            case 20..<50: latencyScore = 3  // Good
            case 50..<100: latencyScore = 2  // Fair
            case 100..<200: latencyScore = 1  // Acceptable
            default: latencyScore = 0  // Poor
            }
        } else {
            latencyScore = 2  // Default to fair if no latency data
        }

        // Calculate speed score (0-4 points)
        // More realistic thresholds for modern connections
        let speedScore: Int
        if let speed = speedResult?.speedMbps {
            switch speed {
            case 50...: speedScore = 4  // Excellent
            case 25..<50: speedScore = 3  // Good
            case 10..<25: speedScore = 2  // Fair
            case 5..<10: speedScore = 1  // Acceptable
            default: speedScore = 0  // Poor
            }
        } else {
            // If no speed test yet, base quality purely on latency
            // Give benefit of doubt since speed test hasn't run
            speedScore = 2
        }

        // Weighted scoring: latency matters slightly more for perceived quality
        // Max score: 8 points (4 from latency + 4 from speed)
        let totalScore = latencyScore + speedScore

        switch totalScore {
        case 7...8: signalQuality = "Excellent"
        case 5...6: signalQuality = "Good"
        case 3...4: signalQuality = "Fair"
        default: signalQuality = "Poor"
        }
    }

    /// Performs a full connectivity check with optional speed test
    public func performCheck(includeSpeedTest: Bool = false) async {
        state = .checking
        errorMessage = nil

        // First, verify real reachability
        let reachabilityResult = await reachabilityService.checkReachability()
        isReachable = reachabilityResult.isReachable
        latencyMs = reachabilityResult.latencyMs
        lastCheckTime = Date()

        // Check additional endpoints
        isGoogleReachable = await checkEndpointReachable(urlString: "https://www.google.com")
        isCloudflareReachable = await checkEndpointReachable(urlString: "https://1.1.1.1")

        if !reachabilityResult.isReachable {
            if let error = reachabilityResult.error {
                errorMessage = error
            }
        }

        // Perform speed test if requested and we're reachable
        if includeSpeedTest && isReachable {
            state = .measuringSpeed
            let speedTestResult = await speedTestService.measureSpeed(quick: false)
            speedResult = speedTestResult

            if let error = speedTestResult.error {
                errorMessage = error
            }
        }

        // Record the check
        historyManager.recordCheck(
            isConnected: isConnected,
            connectionType: connectionType,
            isReachable: isReachable,
            speedMbps: speedResult?.speedMbps,
            latencyMs: rttMs ?? responseTimeMs,  // Use real network RTT, fallback to response time
            isVPNActive: isVPNActive,
            errorMessage: errorMessage
        )

        // Update signal quality and state
        updateSignalQuality()
        updateState()

        // Announce to VoiceOver
        announceStatusChange()
    }

    /// Performs a quick check without speed test
    public func quickCheck() async {
        await performCheck(includeSpeedTest: false)
    }

    /// Performs a full check with speed test
    public func fullCheck() async {
        await performCheck(includeSpeedTest: true)
    }

    // MARK: - Private Methods

    private func setupNetworkMonitorObservation() {
        // Observe network monitor changes
        Task { @MainActor in
            // Initial sync
            syncWithNetworkMonitor()

            // Set up observation using Combine
            networkMonitor.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in
                    guard let self = self else { return }
                    let wasConnected = self.isConnected
                    self.isConnected = connected

                    // If connection state changed, update everything
                    if wasConnected != connected {
                        if connected {
                            // Just connected - run immediate check
                            Task {
                                await self.performRealtimeCheck()
                                await self.performBackgroundSpeedTest()
                            }
                        } else {
                            // Just disconnected - clear stats
                            self.isReachable = false
                            self.isGoogleReachable = false
                            self.isCloudflareReachable = false
                            self.signalQuality = "No Signal"
                            self.speedResult = nil
                            self.latencyMs = nil
                        }
                    }
                    self.updateState()
                }
                .store(in: &cancellables)

            networkMonitor.$connectionType
                .receive(on: DispatchQueue.main)
                .sink { [weak self] type in
                    self?.connectionType = type
                    self?.updateState()
                }
                .store(in: &cancellables)

            networkMonitor.$isVPNActive
                .receive(on: DispatchQueue.main)
                .sink { [weak self] vpnActive in
                    self?.isVPNActive = vpnActive
                }
                .store(in: &cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func syncWithNetworkMonitor() {
        isConnected = networkMonitor.isConnected
        connectionType = networkMonitor.connectionType
        isVPNActive = networkMonitor.isVPNActive
        updateState()

        // Trigger immediate reachability check on network change
        if isConnected {
            Task {
                await performRealtimeCheck()
            }
        } else {
            // When disconnected, clear reachability status
            isReachable = false
            isGoogleReachable = false
            isCloudflareReachable = false
            signalQuality = "No Signal"
            updateState()
        }
    }

    private func updateState() {
        if state == .checking || state == .measuringSpeed {
            return  // Don't interrupt active operations
        }

        if !isConnected {
            state = .offline
            signalQuality = "No Signal"
        } else if isConnected && isReachable {
            state = .online
        } else if isConnected && !isReachable {
            state = .limitedConnectivity
        } else {
            state = .offline
        }
    }

    private func announceStatusChange() {
        var announcement: String
        switch state {
        case .online:
            announcement = "Connected to internet via \(connectionType.displayName)"
            if let speed = speedResult?.speedMbps {
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

// MARK: - Combine Import

// MARK: - AnyCancellable

@available(iOS 17.0, *)
extension ConnectivityViewModel {
    typealias AnyCancellable = Combine.AnyCancellable
}
