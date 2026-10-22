import SwiftUI
import UniformTypeIdentifiers

/// Displays the history of connectivity checks with premium design
/// Note: Requires iOS 17+ for SwiftData integration
@available(iOS 17.0, macOS 14.0, *)
public struct HistoryListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var historyManager: HistoryManager
    @State private var showClearConfirmation = false
    @State private var showExport = false
    @State private var exportDocument = HistoryCSVDocument(text: "")
    @State private var exportError: String?
    private let onExport: () -> Void

    public init(historyManager: HistoryManager, onExport: @escaping () -> Void = {}) {
        self.historyManager = historyManager
        self.onExport = onExport
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !historyManager.recentChecks.isEmpty {
                        Button {
                            do {
                                exportDocument = HistoryCSVDocument(text: try historyManager.exportCSV())
                                showExport = true
                            } catch {
                                exportError = error.localizedDescription
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Export history as CSV")
                        .accessibilityIdentifier("history.export")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !historyManager.recentChecks.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Clear history")
                        .accessibilityIdentifier("history.clear")
                    }
                }
            }
            .fileExporter(
                isPresented: $showExport,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "Online-Now-History"
            ) { result in
                switch result {
                case .success: onExport()
                case .failure(let error): exportError = error.localizedDescription
                }
            }
            .alert("Couldn't Export History", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "Please try again.")
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
            if let error = historyManager.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
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
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("Your connectivity checks will appear here")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityIdentifier("history.empty")
    }

    private var historyContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = historyManager.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
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
        let visibleCount = historyManager.recentChecks.count
        let visibleNoun = visibleCount == 1 ? "check" : "checks"
        let savedNoun = stats.totalChecks == 1 ? "check" : "checks"

        return VStack(alignment: .leading, spacing: 12) {
            Text("Saved Checks Overview")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.75))
                .padding(.leading, 4)

            // Main stats row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 12) {
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
                    icon: "exclamationmark.circle.fill",
                    value: "\(stats.limitedCount)",
                    title: "Limited",
                    color: .orange
                )

                HistoryStatCard(
                    icon: "xmark.circle.fill",
                    value: "\(stats.offlineCount)",
                    title: "Offline",
                    color: .red
                )
            }
            Text("Showing the latest \(visibleCount) \(visibleNoun). Summary and export include \(stats.totalChecks) saved \(savedNoun), up to 100.")
                .font(.footnote)
                .foregroundStyle(Color.primary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            // Average speed if available
            if let avgSpeed = stats.averageSpeedMbps {
                averageSpeedCard(avgSpeed)
            }
        }
    }

    private func averageSpeedCard(_ speed: Double) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Average Speed", systemImage: "speedometer")
                        .font(.footnote)
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    averageSpeedValue(speed)
                    speedQualityBadge(speed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average Speed")
                            .font(.footnote)
                            .foregroundStyle(Color.primary.opacity(0.75))
                        averageSpeedValue(speed)
                    }
                    Spacer()
                    speedQualityBadge(speed)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.averageSpeed")
    }

    @ViewBuilder
    private func averageSpeedValue(_ speed: Double) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", speed))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Mbps")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", speed))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Mbps")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
            }
        }
    }

    private func speedQualityBadge(_ speed: Double) -> some View {
        Text(speedQuality(speed))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(speedQualityColor(speed), in: Capsule())
    }

    private func speedQuality(_ speed: Double) -> String {
        switch speed {
        case 0..<10: return "Poor"
        case 10..<25: return "Fair"
        case 25..<50: return "Good"
        default: return "Excellent"
        }
    }

    private func speedQualityColor(_ speed: Double) -> Color {
        switch speed {
        case 0..<10: return .red
        case 10..<25: return .orange
        case 25..<50: return .green
        default: return .blue
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Checks")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.75))
                .padding(.leading, 4)

            LazyVStack(spacing: 1) {
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
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.primary.opacity(0.75))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let check: ConnectivityCheck

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                expandedContent
            } else {
                compactContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("history.record")
    }

    private var compactContent: some View {
        HStack(spacing: 14) {
            statusIndicator
            VStack(alignment: .leading, spacing: 4) {
                // Status and connection type
                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.subheadline.weight(.semibold))

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(check.connectionType)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary.opacity(0.75))

                    if check.isVPNActive {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 12))
                    }
                }

                // Timestamp
                Text(check.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Speed if available
            if let speed = check.speedMbps {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatSpeed(speed))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("Mbps")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                statusIndicator
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(check.connectionType)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.75))
            if check.isVPNActive {
                Label("Possible VPN", systemImage: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(check.timestamp, format: .dateTime.month(.abbreviated).day())
                Text(check.timestamp, format: .dateTime.hour().minute())
            }
            .font(.caption)
            .foregroundStyle(Color.primary.opacity(0.75))
            if let speed = check.speedMbps {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatSpeed(speed))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("Mbps")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.primary.opacity(0.75))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: statusIcon)
                .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 18, weight: .semibold) : .body.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .accessibilityHidden(true)
    }

    private var statusText: String {
        check.isReachable ? "Online" : (check.isConnected ? "Limited" : "Offline")
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
        parts.append(check.timestamp.formatted(date: .abbreviated, time: .standard))

        if let speed = check.speedMbps {
            parts.append("Speed: \(formatSpeed(speed)) megabits per second")
        }

        if check.isVPNActive {
            parts.append("Possible VPN detected")
        }

        return parts.joined(separator: ", ")
    }
}

/// CSV remains local until the user chooses a destination in the system exporter.
private struct HistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

@available(iOS 17.0, *)
#Preview {
    HistoryListView(historyManager: HistoryManager())
}
