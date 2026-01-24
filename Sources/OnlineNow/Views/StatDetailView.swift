import SwiftUI
import Charts

/// Enum for different stat types
@available(iOS 17.0, *)
public enum StatType: String, CaseIterable, Identifiable {
    case speed = "Speed"
    case latency = "Latency"
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
            return "Latency (ping) measures the time it takes for data to travel to a server and back. Lower latency means more responsive connections, important for video calls and gaming."
        case .quality:
            return "Signal quality is calculated based on your speed and latency. It gives an overall picture of your connection health."
        case .connectionType:
            return "Shows whether you're connected via WiFi, Cellular data, or Ethernet. WiFi typically offers faster speeds, while cellular provides mobility."
        }
    }

    var benchmarks: [(label: String, range: String)] {
        switch self {
        case .speed:
            return [
                ("Excellent", "> 50 Mbps"),
                ("Good", "25-50 Mbps"),
                ("Fair", "10-25 Mbps"),
                ("Poor", "< 10 Mbps")
            ]
        case .latency:
            return [
                ("Excellent", "< 20 ms"),
                ("Good", "20-50 ms"),
                ("Fair", "50-100 ms"),
                ("Poor", "> 100 ms")
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
    let id = UUID()
    let timestamp: Date
    let value: Double
}

/// Detail view shown when tapping on a stat card
@available(iOS 17.0, *)
public struct StatDetailView: View {
    let statType: StatType
    let currentValue: String
    let unit: String
    let historyManager: HistoryManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var chartData: [ChartDataPoint] = []

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
            .onAppear {
                loadChartData()
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
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Current \(statType.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About \(statType.rawValue)", systemImage: "info.circle")
                .font(.headline)

            Text(statType.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("History (Last 20 checks)", systemImage: "chart.xyaxis.line")
                .font(.headline)

            if chartData.isEmpty {
                Text("Not enough data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(statType.rawValue, point.value)
                    )
                    .foregroundStyle(statType.color.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(statType.rawValue, point.value)
                    )
                    .foregroundStyle(statType.color.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Time", point.timestamp),
                        y: .value(statType.rawValue, point.value)
                    )
                    .foregroundStyle(statType.color)
                    .symbolSize(30)
                }
                .chartYAxisLabel(unit)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Benchmarks", systemImage: "ruler")
                .font(.headline)

            ForEach(statType.benchmarks, id: \.label) { benchmark in
                HStack {
                    Text(benchmark.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(benchmark.range)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tips", systemImage: "lightbulb")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tipsForStatType, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                "Quality combines both speed and latency metrics",
                "Excellent quality is ideal for video calls",
                "Fair quality should handle basic browsing",
                "Poor quality may cause streaming issues"
            ]
        case .connectionType:
            return [
                "WiFi is usually faster than cellular",
                "5G cellular can match WiFi speeds",
                "Switch to cellular if WiFi is unstable",
                "Airplane mode disables all connections"
            ]
        }
    }

    private func loadChartData() {
        let checks = historyManager.recentChecks

        switch statType {
        case .speed:
            chartData = checks.compactMap { check in
                guard let speed = check.speedMbps else { return nil }
                return ChartDataPoint(timestamp: check.timestamp, value: speed)
            }.reversed()
        case .latency:
            chartData = checks.compactMap { check in
                guard let latency = check.latencyMs else { return nil }
                return ChartDataPoint(timestamp: check.timestamp, value: latency)
            }.reversed()
        default:
            chartData = []
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
