import SwiftUI
import SwiftData

/// Premium main view with top-tier iOS design
/// Displays current network connectivity status with all features
@available(iOS 17.0, *)
public struct ConnectivityStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ConnectivityViewModel()
    @State private var showHistory = false
    @State private var selectedStatType: StatType?
    @Namespace private var animation

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
                            // Real-time stats cards row (always visible, tappable)
                            statsCardsRow

                            // Network info card with extended details
                            networkInfoCard

                            // Recent activity card
                            if let lastCheck = viewModel.historyManager.lastCheck {
                                recentActivityCard(lastCheck)
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
                .background(backgroundView)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("View history")
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryListView(historyManager: viewModel.historyManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
                viewModel.startMonitoring()
            }
            .onDisappear {
                viewModel.stopMonitoring()
            }
        }
    }

    // MARK: - Stat Value Helpers

    private func currentValueFor(_ statType: StatType) -> String {
        switch statType {
        case .speed:
            if let speed = viewModel.speedResult?.speedMbps {
                return String(format: speed < 10 ? "%.1f" : "%.0f", speed)
            }
            return "—"
        case .latency:
            if let latency = viewModel.latencyMs {
                return String(format: "%.0f", latency)
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
                    Color(.systemBackground)
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
                if viewModel.state == .checking || viewModel.state == .measuringSpeed || viewModel.state == .idle {
                    LoadingRingView(size: min(geometry.size.width * 0.65, 280))
                } else {
                    LogoView(
                        size: min(geometry.size.width * 0.65, 280),
                        isAnimating: false,
                        isOnline: viewModel.state == .online
                    )
                }
            }
            .frame(height: min(geometry.size.width * 0.65, 280))
            .accessibilityHidden(true)

            // App title
            Text("Online Now")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Status text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(statusTitleColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: viewModel.state)

                Text(statusSubtitle)
                    .font(.system(size: 16, weight: .medium))
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
        case .error(let msg): return msg
        }
    }

    private var statusSubtitle: String {
        switch viewModel.state {
        case .checking: return "Verifying your connection"
        case .online:
            var subtitle = "Connected via \(viewModel.connectionType.displayName)"
            if viewModel.isVPNActive {
                subtitle += " • VPN Active"
            }
            if let lastCheck = viewModel.lastCheckTime {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                subtitle += " • Updated \(formatter.localizedString(for: lastCheck, relativeTo: Date()))"
            }
            return subtitle
        case .offline: return "No internet connection detected"
        case .limitedConnectivity: return "Network connected but internet unreachable"
        case .measuringSpeed: return "Downloading test data..."
        case .idle: return "Initializing real-time monitoring..."
        default: return "Monitoring your connection"
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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Speed card - tappable
                MiniStatCard(
                    title: "Speed",
                    value: viewModel.speedResult?.speedMbps != nil ? String(format: viewModel.speedResult!.speedMbps! < 10 ? "%.1f" : "%.0f", viewModel.speedResult!.speedMbps!) : "—",
                    unit: viewModel.speedResult?.speedMbps != nil ? "Mbps" : "",
                    icon: "arrow.down.circle.fill",
                    color: viewModel.speedResult?.speedMbps != nil ? speedColor(viewModel.speedResult!.speedMbps!) : .gray,
                    showChevron: true
                )
                .onTapGesture {
                    selectedStatType = .speed
                }

                // Latency card - tappable
                MiniStatCard(
                    title: "Latency",
                    value: viewModel.latencyMs != nil ? String(format: "%.0f", viewModel.latencyMs!) : "—",
                    unit: viewModel.latencyMs != nil ? "ms" : "",
                    icon: "clock.fill",
                    color: viewModel.latencyMs != nil ? latencyColor(viewModel.latencyMs!) : .gray,
                    showChevron: true
                )
                .onTapGesture {
                    selectedStatType = .latency
                }
            }

            HStack(spacing: 12) {
                // Quality card - tappable
                MiniStatCard(
                    title: "Quality",
                    value: viewModel.signalQuality,
                    unit: "",
                    icon: "chart.bar.fill",
                    color: qualityColor,
                    showChevron: true
                )
                .onTapGesture {
                    selectedStatType = .quality
                }

                // Connection type card - tappable
                MiniStatCard(
                    title: "Type",
                    value: viewModel.connectionType.displayName,
                    unit: "",
                    icon: connectionTypeIcon,
                    color: viewModel.isConnected ? .blue : .gray,
                    showChevron: true
                )
                .onTapGesture {
                    selectedStatType = .connectionType
                }
            }
        }
    }

    private func speedColor(_ speed: Double) -> Color {
        switch speed {
        case 0..<5: return .red
        case 5..<25: return .orange
        case 25..<100: return .green
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

    private var connectionQuality: String {
        return viewModel.signalQuality
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Recent Activity", systemImage: "clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let timeAgo = viewModel.historyManager.timeSinceLastCheck() {
                    Text(timeAgo)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 16) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(check.isReachable ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: check.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(check.isReachable ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(check.isReachable ? "Connection Verified" : "Connection Failed")
                        .font(.system(size: 16, weight: .semibold))

                    HStack(spacing: 8) {
                        Text(check.connectionType)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        if let speed = check.speedMbps {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.1f Mbps", speed))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        if check.isVPNActive {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Label("VPN", systemImage: "lock.shield.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            showHistory = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recent activity: \(check.isReachable ? "Online" : "Offline"), \(viewModel.historyManager.timeSinceLastCheck() ?? "")")
        .accessibilityHint("Tap to view full history")
    }

    // MARK: - Network Info Card

    private var networkInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Network Details", systemImage: "info.circle")
                .font(.system(size: 15, weight: .semibold))
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
                    value: viewModel.isGoogleReachable ? "Reachable" : "Not Reachable",
                    valueColor: viewModel.isGoogleReachable ? .green : .red
                )

                Divider()

                NetworkInfoRow(
                    icon: "server.rack",
                    label: "Cloudflare DNS",
                    value: viewModel.isCloudflareReachable ? "Reachable" : "Not Reachable",
                    valueColor: viewModel.isCloudflareReachable ? .green : .red
                )

                Divider()

                NetworkInfoRow(
                    icon: "waveform.path.ecg",
                    label: "Signal Quality",
                    value: viewModel.signalQuality,
                    valueColor: qualityColor
                )

                if viewModel.isVPNActive {
                    Divider()
                    NetworkInfoRow(
                        icon: "lock.shield.fill",
                        label: "VPN Status",
                        value: "Active",
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
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(title)
                .font(.system(size: 12, weight: .medium))
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
        .contentShape(Rectangle()) // Make entire card tappable
    }
}

struct NetworkInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(valueColor)
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    ConnectivityStatusView()
        .modelContainer(for: ConnectivityCheck.self, inMemory: true)
}
