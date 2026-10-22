import SwiftUI
import Charts

/// Enum for different stat types
/// Note: Requires iOS 17+ for Charts and SwiftData integration
@available(iOS 17.0, macOS 14.0, *)
public enum StatType: String, CaseIterable, Identifiable {
    case speed = "Speed"
    case latency = "TCP Setup Estimate"
    case quality = "Quality"
    case connectionType = "Connection"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .speed: return "arrow.down.circle.fill"
        case .latency: return "clock.fill"
        case .quality: return "chart.bar.fill"
        case .connectionType: return "wifi"
        }
    }

    var color: Color {
        switch self {
        case .speed: return .blue
        case .latency: return .orange
        case .quality: return .green
        case .connectionType: return .purple
        }
    }

    var description: String {
        switch self {
        case .speed:
            return "Download speed measures how fast data can be downloaded to your device. Higher speeds mean faster loading times for websites, videos, and apps."
        case .latency:
            return "The TCP setup estimate times a connection to a public server. It includes connection setup and device scheduling, and is different from an ICMP ping. Lower values usually mean a more responsive connection."
        case .quality:
            return "Connection quality estimates performance from TCP latency and, when you run a speed test, download speed. It does not measure Wi-Fi or cellular radio signal strength."
        case .connectionType:
            return "Shows whether you're connected via WiFi, Cellular data, or Ethernet. WiFi typically offers faster speeds, while cellular provides mobility."
        }
    }

    var benchmarks: [(label: String, range: String)] {
        switch self {
        case .speed:
            return [
                ("Excellent", "50 Mbps or more"),
                ("Good", "25 to under 50 Mbps"),
                ("Fair", "10 to under 25 Mbps"),
                ("Poor", "< 10 Mbps")
            ]
        case .latency:
            return [
                ("Excellent", "< 20 ms"),
                ("Good", "20 to under 50 ms"),
                ("Fair", "50 to under 100 ms"),
                ("Slow", "100 ms or more")
            ]
        case .quality:
            return [
                ("Excellent", "Fast speed + low latency"),
                ("Good", "Solid performance"),
                ("Fair", "Usable but may have issues"),
                ("Poor", "Slow or unstable")
            ]
        case .connectionType:
            return [
                ("WiFi", "Home/office network"),
                ("Cellular", "Mobile data (4G/5G)"),
                ("Ethernet", "Wired connection"),
                ("None", "No connection")
            ]
        }
    }
}

/// Data point for charts
struct ChartDataPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
}

/// Detail view shown when tapping on a stat card
@available(iOS 17.0, *)
public struct StatDetailView: View {
    let statType: StatType
    let currentValue: String
    let unit: String
    @ObservedObject var historyManager: HistoryManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledChartHeight: CGFloat = 200

    public init(statType: StatType, currentValue: String, unit: String, historyManager: HistoryManager) {
        self.statType = statType
        self.currentValue = currentValue
        self.unit = unit
        self.historyManager = historyManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current value hero
                    currentValueSection

                    // Description
                    descriptionSection

                    // Chart (if applicable)
                    if statType == .speed || statType == .latency {
                        chartSection
                    }

                    // Benchmarks
                    benchmarkSection

                    // Tips
                    tipsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(statType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var currentValueSection: some View {
        VStack(spacing: 8) {
            Image(systemName: statType.icon)
                .font(.system(size: 48))
                .foregroundStyle(statType.color)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentValue)
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.75))
                }
            }

            Text(statType == .speed ? "Last Measured Download Speed" : "Current \(statType.rawValue)")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("About \(statType.rawValue)", systemImage: "info.circle")

            Text(statType.description)
                .font(.body)
                .foregroundStyle(Color.primary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statDetail.description")
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("History (Last 20 checks)", systemImage: "chart.xyaxis.line")

            if chartData.isEmpty {
                Text(statType == .speed ? "Run Test Speed to start your speed history." : "Latency history appears after a successful connection check.")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(statType.rawValue, point.value)
                    )
                    .foregroundStyle(plotColor)
                    .interpolationMethod(.linear)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(statType.rawValue, point.value)
                    )
                    .foregroundStyle(plotColor.opacity(0.1).gradient)
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value("Time", point.timestamp),
                        y: .value(statType.rawValue, point.value)
                    )
                    .foregroundStyle(plotColor)
                    .symbolSize(30)
                }
                .chartYAxisLabel {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(Color.primary.opacity(0.75))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: dynamicTypeSize.isAccessibilitySize
                            ? .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
                            : .dateTime.hour().minute())
                            .foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 3 : 5)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel().foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
                // Keep axis labels legible without changing the full-sized
                // section text or the chart's original accessible data values.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? min(480, max(300, scaledChartHeight)) : 200)
                .accessibilityLabel("\(statType.rawValue) history")
                .accessibilityIdentifier("statDetail.plot")
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statDetail.chart")
    }

    private var plotColor: Color {
        statType == .latency ? OnlineNowColors.warningText(in: colorScheme)
            : OnlineNowColors.informationText(in: colorScheme)
    }

    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Benchmarks", systemImage: "ruler")

            ForEach(statType.benchmarks, id: \.label) { benchmark in
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(benchmark.label)
                                .font(.subheadline.weight(.medium))
                            Text(benchmark.range)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.75))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack {
                            Text(benchmark.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(benchmark.range)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.75))
                        }
                    }
                }
                .padding(.vertical, 8)

                if benchmark.label != statType.benchmarks.last?.label {
                    Divider()
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statDetail.benchmarks")
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Tips", systemImage: "lightbulb")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tipsForStatType, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statDetail.tips")
    }

    @ViewBuilder
    private func sectionHeading(_ title: String, systemImage: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        } else {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
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

    private var tipsForStatType: [String] {
        switch statType {
        case .speed:
            return [
                "Move closer to your WiFi router for better speeds",
                "Restart your router if speeds are consistently slow",
                "Check if other devices are using bandwidth",
                "Consider upgrading your internet plan if needed"
            ]
        case .latency:
            return [
                "Use WiFi instead of cellular when possible",
                "Close bandwidth-heavy apps running in background",
                "A wired connection provides the lowest latency",
                "VPNs can sometimes increase latency"
            ]
        case .quality:
            return [
                "Quality estimates performance, not wireless signal strength",
                "Excellent quality is ideal for video calls",
                "Fair quality should handle basic browsing",
                "Poor quality may cause streaming issues"
            ]
        case .connectionType:
            return [
                "WiFi is usually faster than cellular",
                "5G cellular can match WiFi speeds",
                "Switch to cellular if WiFi is unstable",
                "Wi-Fi can be re-enabled while Airplane Mode is on"
            ]
        }
    }

    private var chartData: [ChartDataPoint] {
        let checks = historyManager.recentChecks.prefix(20)

        switch statType {
        case .speed:
            return checks.compactMap { check -> ChartDataPoint? in
                guard let speed = check.speedMbps, speed.isFinite, speed >= 0 else { return nil }
                return ChartDataPoint(id: check.id, timestamp: check.timestamp, value: speed)
            }.sorted { $0.timestamp < $1.timestamp }
        case .latency:
            return checks.compactMap { check -> ChartDataPoint? in
                guard let latency = check.rttMs, latency.isFinite, latency >= 0 else { return nil }
                return ChartDataPoint(id: check.id, timestamp: check.timestamp, value: latency)
            }.sorted { $0.timestamp < $1.timestamp }
        default:
            return []
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        StatDetailView(
            statType: .speed,
            currentValue: "45.2",
            unit: "Mbps",
            historyManager: HistoryManager()
        )
    }
}
