import SwiftUI

/// Displays the history of connectivity checks with premium design
/// Note: Requires iOS 17+ for SwiftData integration
@available(iOS 17.0, macOS 14.0, *)
public struct HistoryListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var historyManager: HistoryManager
    @State private var showClearConfirmation = false

    public init(historyManager: HistoryManager) {
        self.historyManager = historyManager
    }

    public var body: some View {
        NavigationStack {
            Group {
                if historyManager.recentChecks.isEmpty {
                    emptyStateView
                } else {
                    historyContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !historyManager.recentChecks.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Clear history")
                    }
                }
            }
            .confirmationDialog(
                "Clear History",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    withAnimation {
                        historyManager.clearHistory()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all connectivity check history. This action cannot be undone.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("No History Yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Your connectivity checks will appear here")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Statistics cards
                statisticsSection

                // History list
                historySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var statisticsSection: some View {
        let stats = historyManager.getStatistics()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            // Main stats row
            HStack(spacing: 12) {
                HistoryStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "\(stats.totalChecks)",
                    title: "Total",
                    color: .blue
                )

                HistoryStatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(stats.onlineCount)",
                    title: "Online",
                    color: .green
                )

                HistoryStatCard(
                    icon: "xmark.circle.fill",
                    value: "\(stats.offlineCount)",
                    title: "Offline",
                    color: .red
                )
            }

            // Average speed if available
            if let avgSpeed = stats.averageSpeedMbps {
                HStack(spacing: 12) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average Speed")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", avgSpeed))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("Mbps")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Speed quality badge
                    Text(speedQuality(avgSpeed))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(speedQualityColor(avgSpeed), in: Capsule())
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func speedQuality(_ speed: Double) -> String {
        switch speed {
        case 0..<5: return "Poor"
        case 5..<25: return "Fair"
        case 25..<100: return "Good"
        default: return "Great"
        }
    }

    private func speedQualityColor(_ speed: Double) -> Color {
        switch speed {
        case 0..<5: return .red
        case 5..<25: return .orange
        case 25..<100: return .green
        default: return .blue
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Checks")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 1) {
                ForEach(Array(historyManager.recentChecks.enumerated()), id: \.element.id) { index, check in
                    HistoryRowView(check: check)
                        .background(cardBackground)
                        .clipShape(
                            RoundedCorners(
                                radius: 16,
                                corners: cornerStyle(for: index)
                            )
                        )
                }
            }
        }
    }

    private func cornerStyle(for index: Int) -> UIRectCorner {
        let count = historyManager.recentChecks.count
        if count == 1 {
            return .allCorners
        } else if index == 0 {
            return [.topLeft, .topRight]
        } else if index == count - 1 {
            return [.bottomLeft, .bottomRight]
        } else {
            return []
        }
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(.systemGray6)
            } else {
                Color.white
            }
        }
    }
}

/// Custom rounded corners shape
struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// Statistics card for history view
@available(iOS 17.0, *)
struct HistoryStatCard: View {
    let icon: String
    let value: String
    let title: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            Group {
                if colorScheme == .dark {
                    Color(.systemGray6)
                } else {
                    Color.white
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
/// Individual row for a connectivity check
@available(iOS 17.0, *)
struct HistoryRowView: View {
    let check: ConnectivityCheck

    var body: some View {
        HStack(spacing: 14) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Status and connection type
                HStack(spacing: 6) {
                    Text(check.isReachable ? "Online" : (check.isConnected ? "Limited" : "Offline"))
                        .font(.system(size: 15, weight: .semibold))

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(check.connectionType)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    if check.isVPNActive {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 12))
                    }
                }

                // Timestamp
                Text(check.timestamp, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Speed if available
            if let speed = check.speedMbps {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatSpeed(speed))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Mbps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var statusColor: Color {
        if check.isReachable {
            return .green
        } else if check.isConnected {
            return .orange
        } else {
            return .red
        }
    }

    private var statusIcon: String {
        if check.isReachable {
            return "checkmark"
        } else if check.isConnected {
            return "exclamationmark"
        } else {
            return "xmark"
        }
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed < 1 {
            return String(format: "%.2f", speed)
        } else if speed < 10 {
            return String(format: "%.1f", speed)
        } else {
            return String(format: "%.0f", speed)
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = []

        if check.isReachable {
            parts.append("Online")
        } else if check.isConnected {
            parts.append("Limited connectivity")
        } else {
            parts.append("Offline")
        }

        parts.append("via \(check.connectionType)")

        if let speed = check.speedMbps {
            parts.append("Speed: \(formatSpeed(speed)) megabits per second")
        }

        if check.isVPNActive {
            parts.append("VPN active")
        }

        return parts.joined(separator: ", ")
    }
}

@available(iOS 17.0, *)
#Preview {
    HistoryListView(historyManager: HistoryManager())
}
