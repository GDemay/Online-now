import SwiftUI
import Combine

// MARK: - Haptic Feedback Manager

#if os(iOS)
import UIKit

/// Manages haptic feedback for connectivity state changes
@available(iOS 15.0, *)
public final class HapticFeedbackManager {

    public static let shared = HapticFeedbackManager()

    private var isEnabled: Bool = true

    private init() {}

    /// Enable or disable haptic feedback
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Trigger haptic feedback for connection drop
    public func connectionDropped() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Trigger haptic feedback for connection restored
    public func connectionRestored() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Trigger haptic feedback for captive portal detection
    public func captivePortalDetected() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Light impact for status changes
    public func statusChanged() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Medium impact for important events
    public func importantEvent() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}
#endif

// MARK: - Banner Configuration

/// Configuration options for the connectivity banner
@available(iOS 15.0, macOS 12.0, *)
public struct ConnectivityBannerConfiguration {
    /// Banner display mode
    public enum DisplayMode {
        /// Show banner only when disconnected
        case disconnectedOnly
        /// Show banner for disconnected and captive portal states
        case problemsOnly
        /// Always show banner with current status
        case always
    }

    /// Banner position on screen
    public enum Position {
        case top
        case bottom
    }

    /// Animation style for banner appearance
    public enum AnimationStyle {
        case slide
        case fade
        case spring
    }

    public let displayMode: DisplayMode
    public let position: Position
    public let animationStyle: AnimationStyle
    public let showIcon: Bool
    public let showLatency: Bool
    public let hapticFeedback: Bool
    public let autoDismissDelay: TimeInterval?
    public let customColors: BannerColors?

    public init(
        displayMode: DisplayMode = .problemsOnly,
        position: Position = .top,
        animationStyle: AnimationStyle = .spring,
        showIcon: Bool = true,
        showLatency: Bool = false,
        hapticFeedback: Bool = true,
        autoDismissDelay: TimeInterval? = nil,
        customColors: BannerColors? = nil
    ) {
        self.displayMode = displayMode
        self.position = position
        self.animationStyle = animationStyle
        self.showIcon = showIcon
        self.showLatency = showLatency
        self.hapticFeedback = hapticFeedback
        self.autoDismissDelay = autoDismissDelay
        self.customColors = customColors
    }

    /// Default configuration for most apps
    public static let `default` = ConnectivityBannerConfiguration()

    /// Minimal configuration showing only disconnected state
    public static let minimal = ConnectivityBannerConfiguration(
        displayMode: .disconnectedOnly,
        showIcon: true,
        showLatency: false
    )

    /// Verbose configuration showing all states
    public static let verbose = ConnectivityBannerConfiguration(
        displayMode: .always,
        showIcon: true,
        showLatency: true
    )

    /// Netflix-style banner (bottom, auto-dismiss)
    public static let netflixStyle = ConnectivityBannerConfiguration(
        displayMode: .problemsOnly,
        position: .bottom,
        animationStyle: .spring,
        showIcon: true,
        showLatency: false,
        hapticFeedback: true,
        autoDismissDelay: 5.0
    )
}

/// Custom colors for the banner
@available(iOS 15.0, macOS 12.0, *)
public struct BannerColors {
    public let connectedBackground: Color
    public let connectedForeground: Color
    public let disconnectedBackground: Color
    public let disconnectedForeground: Color
    public let captivePortalBackground: Color
    public let captivePortalForeground: Color

    public init(
        connectedBackground: Color = .green,
        connectedForeground: Color = .white,
        disconnectedBackground: Color = .red,
        disconnectedForeground: Color = .white,
        captivePortalBackground: Color = .orange,
        captivePortalForeground: Color = .white
    ) {
        self.connectedBackground = connectedBackground
        self.connectedForeground = connectedForeground
        self.disconnectedBackground = disconnectedBackground
        self.disconnectedForeground = disconnectedForeground
        self.captivePortalBackground = captivePortalBackground
        self.captivePortalForeground = captivePortalForeground
    }
}

// MARK: - Banner View Model

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class ConnectivityBannerViewModel: ObservableObject {
    @Published var status: ConnectivityStatus = .checking
    @Published var metadata: NetworkMetadata = .empty
    @Published var isVisible: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var previousStatus: ConnectivityStatus = .checking
    private let configuration: ConnectivityBannerConfiguration
    private let reachabilityService = ReachabilityService()
    private var monitoringTask: Task<Void, Never>?

    init(configuration: ConnectivityBannerConfiguration) {
        self.configuration = configuration
    }

    func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                // Check connectivity
                let (reachability, captivePortal) = await self.reachabilityService.checkConnectivity()

                let newStatus: ConnectivityStatus
                if captivePortal.isCaptivePortal {
                    newStatus = .captivePortal
                } else if reachability.isReachable {
                    newStatus = .connected
                } else {
                    newStatus = .disconnected
                }

                // Update on main thread
                await MainActor.run {
                    self.updateStatus(newStatus, latency: reachability.latencyMs)
                }

                // Check every 5 seconds
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func updateStatus(_ newStatus: ConnectivityStatus, latency: Double) {
        let wasConnected = previousStatus == .connected
        let isNowConnected = newStatus == .connected

        // Trigger haptic feedback on state changes
        #if os(iOS)
        if configuration.hapticFeedback && previousStatus != newStatus {
            if wasConnected && !isNowConnected {
                HapticFeedbackManager.shared.connectionDropped()
            } else if !wasConnected && isNowConnected {
                HapticFeedbackManager.shared.connectionRestored()
            } else if newStatus == .captivePortal {
                HapticFeedbackManager.shared.captivePortalDetected()
            }
        }
        #endif

        previousStatus = status
        status = newStatus
        metadata = NetworkMetadata(latencyMs: latency, signalQuality: .unknown)

        // Update visibility based on configuration
        updateVisibility()
    }

    private func updateVisibility() {
        switch configuration.displayMode {
        case .disconnectedOnly:
            isVisible = status == .disconnected
        case .problemsOnly:
            isVisible = status == .disconnected || status == .captivePortal
        case .always:
            isVisible = true
        }

        // Handle auto-dismiss
        if isVisible, let delay = configuration.autoDismissDelay, status == .connected {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if self.status == .connected {
                    self.isVisible = false
                }
            }
        }
    }
}

// MARK: - Banner View

@available(iOS 15.0, macOS 12.0, *)
struct ConnectivityBannerView: View {
    @ObservedObject var viewModel: ConnectivityBannerViewModel
    let configuration: ConnectivityBannerConfiguration

    var body: some View {
        if viewModel.isVisible {
            bannerContent
                .transition(bannerTransition)
        }
    }

    private var bannerContent: some View {
        HStack(spacing: 8) {
            if configuration.showIcon {
                statusIcon
            }

            statusText

            if configuration.showLatency, let latency = viewModel.metadata.latencyMs {
                Text("(\(Int(latency))ms)")
                    .font(.caption)
                    .opacity(0.8)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
    }

    private var statusIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 14, weight: .semibold))
    }

    private var statusText: some View {
        Text(statusMessage)
            .font(.system(size: 14, weight: .medium))
    }

    private var iconName: String {
        switch viewModel.status {
        case .connected:
            return "wifi"
        case .disconnected:
            return "wifi.slash"
        case .captivePortal:
            return "exclamationmark.triangle"
        case .localOnly:
            return "wifi.exclamationmark"
        case .checking:
            return "arrow.clockwise"
        }
    }

    private var statusMessage: String {
        switch viewModel.status {
        case .connected:
            return "Connected"
        case .disconnected:
            return "No Internet Connection"
        case .captivePortal:
            return "Login Required"
        case .localOnly:
            return "Limited Connectivity"
        case .checking:
            return "Checking..."
        }
    }

    private var backgroundColor: Color {
        if let colors = configuration.customColors {
            switch viewModel.status {
            case .connected:
                return colors.connectedBackground
            case .disconnected:
                return colors.disconnectedBackground
            case .captivePortal:
                return colors.captivePortalBackground
            default:
                return Color.gray
            }
        }

        switch viewModel.status {
        case .connected:
            return Color.green
        case .disconnected:
            return Color.red
        case .captivePortal:
            return Color.orange
        case .localOnly:
            return Color.yellow
        case .checking:
            return Color.gray
        }
    }

    private var foregroundColor: Color {
        if let colors = configuration.customColors {
            switch viewModel.status {
            case .connected:
                return colors.connectedForeground
            case .disconnected:
                return colors.disconnectedForeground
            case .captivePortal:
                return colors.captivePortalForeground
            default:
                return Color.white
            }
        }

        return Color.white
    }

    private var bannerTransition: AnyTransition {
        switch configuration.animationStyle {
        case .slide:
            return configuration.position == .top
                ? .move(edge: .top)
                : .move(edge: .bottom)
        case .fade:
            return .opacity
        case .spring:
            return configuration.position == .top
                ? .move(edge: .top).combined(with: .opacity)
                : .move(edge: .bottom).combined(with: .opacity)
        }
    }
}

// MARK: - View Modifier

@available(iOS 15.0, macOS 12.0, *)
struct ConnectivityBannerModifier: ViewModifier {
    let configuration: ConnectivityBannerConfiguration
    @StateObject private var viewModel: ConnectivityBannerViewModel

    init(configuration: ConnectivityBannerConfiguration) {
        self.configuration = configuration
        _viewModel = StateObject(wrappedValue: ConnectivityBannerViewModel(configuration: configuration))
    }

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                if configuration.position == .top {
                    ConnectivityBannerView(viewModel: viewModel, configuration: configuration)
                    Spacer()
                } else {
                    Spacer()
                    ConnectivityBannerView(viewModel: viewModel, configuration: configuration)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isVisible)
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

// MARK: - View Extension

@available(iOS 15.0, macOS 12.0, *)
public extension View {
    /// Add a connectivity banner overlay to this view
    /// - Parameter configuration: Banner configuration options
    /// - Returns: View with connectivity banner overlay
    func connectivityBanner(
        _ configuration: ConnectivityBannerConfiguration = .default
    ) -> some View {
        modifier(ConnectivityBannerModifier(configuration: configuration))
    }

    /// Add a Netflix-style connectivity banner
    func netflixConnectivityBanner() -> some View {
        connectivityBanner(.netflixStyle)
    }

    /// Add a minimal connectivity banner (disconnected only)
    func minimalConnectivityBanner() -> some View {
        connectivityBanner(.minimal)
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 15.0, macOS 12.0, *)
struct ConnectivityBannerModifier_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("App Content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.2))
        }
        .connectivityBanner(.default)
        .previewDisplayName("Default Banner")

        VStack {
            Text("App Content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.2))
        }
        .netflixConnectivityBanner()
        .previewDisplayName("Netflix Style")
    }
}
#endif
