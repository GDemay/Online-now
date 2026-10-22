import SwiftData
import SwiftUI

/// Displays current network connectivity and user-initiated measurements.
/// Note: Requires iOS 17+ for SwiftData integration. For iOS 15+ use ConnectivityBanner.
@available(iOS 17.0, macOS 14.0, *)
public struct ConnectivityStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel = ConnectivityViewModel()
    @State private var showHistory = false
    @State private var showTipJar = false
    @State private var selectedStatType: StatType?
    @State private var actionTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero section with logo
                        heroSection(geometry: geometry)

                        // Main content
                        VStack(spacing: 20) {
                            measurementActions

                            // Real-time stats cards row (always visible, tappable)
                            statsCardsRow

                            // Network info card with extended details
                            networkInfoCard

                            // Recent activity card
                            if let lastCheck = viewModel.historyManager.lastCheck {
                                recentActivityCard(lastCheck)
                            }

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
                .refreshable {
                    await viewModel.quickCheck()
                }
                .background(backgroundView)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTipJar = true
                    } label: {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(minWidth: 44, minHeight: 44)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .accessibilityIdentifier("navigation.tipJar")
                    .accessibilityLabel("Support developer")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("View history")
                    .accessibilityIdentifier("navigation.history")
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryListView(historyManager: viewModel.historyManager) {
                    viewModel.tippingManager.recordHistoryExported()
                }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView(tippingManager: viewModel.tippingManager)
            }
            .sheet(item: $selectedStatType) { statType in
                StatDetailView(
                    statType: statType,
                    currentValue: currentValueFor(statType),
                    unit: unitFor(statType),
                    historyManager: viewModel.historyManager
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                viewModel.historyManager.configure(with: modelContext)
                if scenePhase == .active {
                    viewModel.startMonitoring()
                }
            }
            .onDisappear {
                actionTask?.cancel()
                viewModel.stopMonitoring()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.startMonitoring()
                } else {
                    actionTask?.cancel()
                    viewModel.stopMonitoring()
                }
            }
            // Screenshot values must never replace real measurements in a release build.
            #if DEBUG
            .onTapGesture(count: 3) {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.togglePreviewMode()
                }
            }
            .onTapGesture(count: 1) {
                if viewModel.isPreviewMode {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.cyclePreviewState()
                    }
                }
            }
            #endif
            .accessibilityHidden(viewModel.tippingManager.shouldShowTipPrompt)
            .overlay(alignment: .top) {
                // Preview mode indicator
                if viewModel.isPreviewMode {
                    PreviewModeBanner(
                        currentState: viewModel.previewState,
                        onCycleState: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.cyclePreviewState()
                            }
                        },
                        onExitPreview: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.togglePreviewMode()
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                // Contextual tip prompt
                if viewModel.tippingManager.shouldShowTipPrompt,
                    let trigger = viewModel.tippingManager.tipPromptTrigger
                {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.tippingManager.dismissTipPrompt()
                            }

                        TipPromptView(
                            trigger: trigger,
                            onShowTipJar: {
                                viewModel.tippingManager.dismissTipPrompt()
                                showTipJar = true
                            },
                            onDismiss: {
                                viewModel.tippingManager.dismissTipPrompt()
                            }
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
    }

    // MARK: - Stat Value Helpers

    private var isBusy: Bool {
        viewModel.isPerformingCheck || viewModel.isPerformingSpeedTest
    }

    private var measurementActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { refreshButton; speedTestButton }
            } else {
                HStack(spacing: 12) { refreshButton; speedTestButton }
            }
            Text("Speed tests download data and use your current Wi-Fi or mobile plan. They run only when you choose Test Speed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("measurementError")
            }
        }
    }

    private var refreshButton: some View {
        Button {
            actionTask = Task { await viewModel.quickCheck() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(isBusy || viewModel.isPreviewMode)
        .accessibilityIdentifier("connectivity.refresh")
        .accessibilityHint("Checks internet access without running a speed test")
    }

    private var speedTestButton: some View {
        Button {
            actionTask = Task { await viewModel.fullCheck() }
        } label: {
            HStack {
                if viewModel.isPerformingSpeedTest { ProgressView().tint(.white) }
                Label(viewModel.isPerformingSpeedTest ? "Testing…" : "Test Speed", systemImage: "speedometer")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy || !viewModel.isConnected || viewModel.isPreviewMode)
        .accessibilityIdentifier("connectivity.speedTest")
        .accessibilityHint("Downloads test data to measure your connection speed")
    }

    private func currentValueFor(_ statType: StatType) -> String {
        switch statType {
        case .speed:
            if let speed = viewModel.speedResult?.speedMbps {
                return String(format: speed < 10 ? "%.1f" : "%.0f", speed)
            }
            return "—"
        case .latency:
            // TCP setup timing is kept separate from full HTTP response time.
            if let rtt = viewModel.rttMs {
                return String(format: "%.0f", rtt)
            }
            return "—"
        case .quality:
            return viewModel.signalQuality
        case .connectionType:
            return viewModel.connectionType.displayName
        }
    }

    private func unitFor(_ statType: StatType) -> String {
        switch statType {
        case .speed: return "Mbps"
        case .latency: return "ms"
        case .quality, .connectionType: return ""
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    statusBackgroundColor.opacity(0.15),
                    Color(.systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle pattern overlay
            if colorScheme == .dark {
                Color.black.opacity(0.3)
            }
        }
        .ignoresSafeArea()
    }

    private var statusBackgroundColor: Color {
        switch viewModel.state {
        case .online: return .green
        case .offline: return .red
        case .limitedConnectivity: return .orange
        case .checking, .measuringSpeed: return .blue
        default: return .gray
        }
    }

    // MARK: - Hero Section

    private func heroSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
                if viewModel.state == .checking || viewModel.state == .measuringSpeed
                    || viewModel.state == .idle
                {
                    LoadingRingView(size: min(geometry.size.width * 0.5, 200))
                } else {
                    LogoView(
                        size: min(geometry.size.width * 0.5, 200),
                        isAnimating: false,
                        isOnline: viewModel.state == .online
                    )
                }
            }
            .frame(height: min(geometry.size.width * 0.5, 200))
            .accessibilityHidden(true)

            // App title
            Text("Online Now")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            // Status text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusTitleColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: viewModel.state)

                Text(statusSubtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityStatusLabel)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var statusTitle: String {
        switch viewModel.state {
        case .idle: return "Connecting..."
        case .checking: return "Checking..."
        case .online: return "You're Online"
        case .offline: return "You're Offline"
        case .limitedConnectivity: return "Limited Access"
        case .measuringSpeed: return "Testing Speed..."
        case .error: return "Couldn't Check Connection"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.state {
        case .checking: return "Verifying your connection"
        case .online:
            var subtitle = "Connected via \(viewModel.connectionType.displayName)"
            if viewModel.isVPNActive {
                subtitle += " • Possible VPN"
            }
            if let lastCheck = viewModel.lastCheckTime {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let now = Date()
                let elapsed = now.timeIntervalSince(lastCheck)
                subtitle += elapsed < 1 ? " • Updated just now" :
                    " • Updated \(formatter.localizedString(for: lastCheck, relativeTo: now))"
            }
            return subtitle
        case .offline: return "No internet connection detected"
        case .limitedConnectivity: return "Network connected but internet unreachable"
        case .measuringSpeed: return "Downloading test data..."
        case .idle: return "Initializing real-time monitoring..."
        case .error(let message): return message
        }
    }

    private var statusTitleColor: Color {
        switch viewModel.state {
        case .online: return .green
        case .offline: return .red
        case .limitedConnectivity: return .orange
        case .checking, .measuringSpeed: return .blue
        default: return .primary
        }
    }

    private var accessibilityStatusLabel: String {
        "\(statusTitle). \(statusSubtitle)"
    }

    // MARK: - Stats Cards

    private var statsCardsRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                Button { selectedStatType = .speed } label: {
                // Speed card - tappable
                MiniStatCard(
                    title: "Last Download Speed",
                    value: currentValueFor(.speed),
                    unit: viewModel.speedResult?.speedMbps != nil ? "Mbps" : "",
                    icon: "arrow.down.circle.fill",
                    color: (viewModel.speedResult?.speedMbps).map(speedColor) ?? .gray,
                    showChevron: true
                )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("connectivity.speed")
                .accessibilityLabel("Download speed, \(currentValueFor(.speed)) megabits per second")
                .accessibilityHint("View speed details and history")

                // TCP setup timing includes connection setup and local scheduling.
                Button { selectedStatType = .latency } label: { MiniStatCard(
                    title: "TCP Setup Estimate",
                    value: currentValueFor(.latency),
                    unit: viewModel.rttMs != nil ? "ms" : "",
                    icon: "timer",
                    color: viewModel.rttMs.map(latencyColor) ?? .gray,
                    showChevron: true
                )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("connectivity.latency")
                .accessibilityLabel("TCP setup estimate, \(currentValueFor(.latency)) milliseconds")

                // Quality card - tappable
                Button { selectedStatType = .quality } label: { MiniStatCard(
                    title: "Quality",
                    value: viewModel.signalQuality,
                    unit: "",
                    icon: "chart.bar.fill",
                    color: qualityColor,
                    showChevron: true
                )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("connectivity.quality")
                .accessibilityLabel("Connection quality, \(viewModel.signalQuality)")

                // Connection type card - tappable
                Button { selectedStatType = .connectionType } label: { MiniStatCard(
                    title: "Type",
                    value: viewModel.connectionType.displayName,
                    unit: "",
                    icon: connectionTypeIcon,
                    color: viewModel.isConnected ? .blue : .gray,
                    showChevron: true
                )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("connectivity.type")
                .accessibilityLabel("Connection type, \(viewModel.connectionType.displayName)")
        }
    }

    private func speedColor(_ speed: Double) -> Color {
        switch speed {
        case 0..<10: return .red
        case 10..<25: return .orange
        case 25..<50: return .green
        default: return .blue
        }
    }

    private func latencyColor(_ latency: Double) -> Color {
        switch latency {
        case 0..<50: return .green
        case 50..<100: return .orange
        default: return .red
        }
    }

    private var qualityColor: Color {
        switch viewModel.signalQuality {
        case "Excellent": return .green
        case "Good": return .blue
        case "Fair": return .orange
        case "Poor": return .red
        default: return .gray
        }
    }

    // MARK: - Recent Activity Card

    private func recentActivityCard(_ check: ConnectivityCheck) -> some View {
        Button { showHistory = true } label: {
        VStack(alignment: .leading, spacing: 16) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 16))
            headerLayout {
                Label("Recent Activity", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 16) }
                if let timeAgo = viewModel.historyManager.timeSinceLastCheck() {
                    Text(timeAgo)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }

            let contentLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 16))
            contentLayout {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(
                            check.isReachable ? Color.green.opacity(0.15) : Color.red.opacity(0.15)
                        )
                        .frame(width: 44, height: 44)

                    Image(
                        systemName: check.isReachable
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.system(size: 22))
                    .foregroundStyle(check.isReachable ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(check.isReachable ? "Connection Verified" : "Connection Failed")
                        .font(.body.weight(.semibold))

                    let detailLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                        : AnyLayout(HStackLayout(spacing: 8))
                    detailLayout {
                        Text(check.connectionType)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let speed = check.speedMbps {
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text("•").foregroundStyle(.tertiary)
                            }
                            Text(String(format: "%.1f Mbps", speed))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if check.isVPNActive {
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text("•").foregroundStyle(.tertiary)
                            }
                            Label("Possible VPN", systemImage: "lock.shield.fill")
                                .font(.footnote)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Recent activity: \(check.isReachable ? "Online" : (check.isConnected ? "Limited connectivity" : "Offline")), \(viewModel.historyManager.timeSinceLastCheck() ?? "")"
        )
        .accessibilityHint("Tap to view full history")
        .accessibilityIdentifier("connectivity.recentActivity")
    }

    // MARK: - Network Info Card

    private var networkInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Network Details", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                NetworkInfoRow(
                    icon: connectionTypeIcon,
                    label: "Connection Type",
                    value: viewModel.connectionType.displayName
                )

                Divider()

                NetworkInfoRow(
                    icon: "checkmark.seal.fill",
                    label: "Internet Reachability",
                    value: viewModel.isReachable ? "Verified" : "Not Verified",
                    valueColor: viewModel.isReachable ? .green : .orange
                )

                Divider()

                NetworkInfoRow(
                    icon: "g.circle.fill",
                    label: "Google",
                    value: endpointStatus(viewModel.isGoogleReachable),
                    valueColor: viewModel.isGoogleReachable ? .green : .secondary
                )

                Divider()

                NetworkInfoRow(
                    icon: "server.rack",
                    label: "Cloudflare HTTPS",
                    value: endpointStatus(viewModel.isCloudflareReachable),
                    valueColor: viewModel.isCloudflareReachable ? .green : .secondary
                )

                Divider()

                NetworkInfoRow(
                    icon: "waveform.path.ecg",
                    label: "Connection Quality",
                    value: viewModel.signalQuality,
                    valueColor: qualityColor
                )

                if viewModel.isConstrained || viewModel.isExpensive {
                    Divider()
                    NetworkInfoRow(
                        icon: "antenna.radiowaves.left.and.right",
                        label: "Data Usage",
                        value: viewModel.isConstrained ? "Low Data Mode" : "Metered connection",
                        valueColor: .orange
                    )
                }

                if let responseTime = viewModel.responseTimeMs {
                    Divider()
                    NetworkInfoRow(
                        icon: "network",
                        label: "HTTP Response Time",
                        value: String(format: "%.0f ms", responseTime)
                    )
                }

                if viewModel.isVPNActive {
                    Divider()
                    NetworkInfoRow(
                        icon: "lock.shield.fill",
                        label: "VPN Detection",
                        value: "Tunnel detected",
                        valueColor: .blue
                    )
                }

                if let lastCheck = viewModel.lastCheckTime {
                    Divider()
                    NetworkInfoRow(
                        icon: "clock.arrow.circlepath",
                        label: "Last Updated",
                        value: formatTime(lastCheck),
                        valueColor: .secondary
                    )
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func endpointStatus(_ reachable: Bool) -> String {
        if viewModel.isPerformingCheck { return "Checking…" }
        if viewModel.lastCheckTime == nil { return "Not checked" }
        return reachable ? "Reachable" : "No response"
    }

    private var connectionTypeIcon: String {
        switch viewModel.connectionType {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .unknown, .none: return "questionmark.circle"
        }
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(.systemGray6)
            } else {
                Color.white
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct MiniStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    var showChevron: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Group {
                if colorScheme == .dark {
                    Color(.systemGray6)
                } else {
                    Color.white
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())  // Make entire card tappable
    }
}

// MARK: - Preview Mode Banner

/// Banner shown at top when in preview/screenshot mode
@available(iOS 17.0, macOS 14.0, *)
struct PreviewModeBanner: View {
    let currentState: AppState
    let onCycleState: () -> Void
    let onExitPreview: () -> Void

    private var stateLabel: String {
        switch currentState {
        case .online: return "🟢 Online"
        case .offline: return "🔴 Offline"
        case .limitedConnectivity: return "🟠 Limited"
        case .checking: return "🔵 Checking"
        case .measuringSpeed: return "🔵 Speed Test"
        default: return "Preview"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 14, weight: .semibold))

            Text("SCREENSHOT MODE")
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Spacer()

            // Current state indicator
            Button(action: onCycleState) {
                Text(stateLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
            }

            Button(action: onExitPreview) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct NetworkInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        labelContent.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 16)
                        valueContent.fixedSize(horizontal: true, vertical: false)
                    }
                    verticalContent
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var labelContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valueContent: some View {
        Text(value)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(valueColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            labelContent
            valueContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.0, *)
#Preview {
    ConnectivityStatusView()
        .modelContainer(for: ConnectivityCheck.self, inMemory: true)
}
