import Foundation
import SwiftData

/// Manages the local history of connectivity checks using SwiftData
/// Note: Requires iOS 17+ for SwiftData. Core SDK features work on iOS 15+.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class HistoryManager: ObservableObject {

    /// Maximum number of checks to retain
    private let maxHistoryCount = 100

    /// The SwiftData model context
    private var modelContext: ModelContext?

    /// Recently fetched checks (cached for performance)
    @Published public private(set) var recentChecks: [ConnectivityCheck] = []

    /// The most recent check
    @Published public private(set) var lastCheck: ConnectivityCheck?

    public init() {}

    /// Configure the manager with a model context
    public func configure(with context: ModelContext) {
        self.modelContext = context
        fetchRecentChecks()
    }

    /// Saves a new connectivity check
    public func saveCheck(_ check: ConnectivityCheck) {
        guard let context = modelContext else { return }

        context.insert(check)

        do {
            try context.save()
            lastCheck = check
            fetchRecentChecks()
            pruneOldChecks()
        } catch {
            print("Failed to save connectivity check: \(error)")
        }
    }

    /// Creates and saves a new check from current state
    public func recordCheck(
        isConnected: Bool,
        connectionType: ConnectionType,
        isReachable: Bool,
        speedMbps: Double? = nil,
        latencyMs: Double? = nil,
        isVPNActive: Bool = false,
        errorMessage: String? = nil
    ) {
        let check = ConnectivityCheck(
            isConnected: isConnected,
            connectionType: connectionType.rawValue,
            isReachable: isReachable,
            speedMbps: speedMbps,
            latencyMs: latencyMs,
            isVPNActive: isVPNActive,
            errorMessage: errorMessage
        )
        saveCheck(check)
    }

    /// Fetches the most recent checks
    public func fetchRecentChecks(limit: Int = 20) {
        guard let context = modelContext else { return }

        do {
            var descriptor = FetchDescriptor<ConnectivityCheck>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit

            recentChecks = try context.fetch(descriptor)
            lastCheck = recentChecks.first
        } catch {
            print("Failed to fetch recent checks: \(error)")
            recentChecks = []
        }
    }

    /// Fetches all checks within a date range
    public func fetchChecks(from startDate: Date, to endDate: Date) -> [ConnectivityCheck] {
        guard let context = modelContext else { return [] }

        do {
            let predicate = #Predicate<ConnectivityCheck> {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            }
            var descriptor = FetchDescriptor<ConnectivityCheck>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch checks in date range: \(error)")
            return []
        }
    }

    /// Returns time since last check as a formatted string
    public func timeSinceLastCheck() -> String? {
        guard let lastCheck = lastCheck else { return nil }

        let interval = Date().timeIntervalSince(lastCheck.timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    /// Removes old checks beyond the retention limit
    private func pruneOldChecks() {
        guard let context = modelContext else { return }

        do {
            var descriptor = FetchDescriptor<ConnectivityCheck>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            let allChecks = try context.fetch(descriptor)

            if allChecks.count > maxHistoryCount {
                let checksToDelete = allChecks.dropFirst(maxHistoryCount)
                for check in checksToDelete {
                    context.delete(check)
                }
                try context.save()
            }
        } catch {
            print("Failed to prune old checks: \(error)")
        }
    }

    /// Clears all history
    public func clearHistory() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<ConnectivityCheck>()
            let allChecks = try context.fetch(descriptor)

            for check in allChecks {
                context.delete(check)
            }
            try context.save()

            recentChecks = []
            lastCheck = nil
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    /// Statistics for display
    public func getStatistics() -> HistoryStatistics {
        let total = recentChecks.count
        let online = recentChecks.filter { $0.isConnected && $0.isReachable }.count
        let offline = total - online

        let speeds = recentChecks.compactMap { $0.speedMbps }
        let avgSpeed = speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)

        return HistoryStatistics(
            totalChecks: total,
            onlineCount: online,
            offlineCount: offline,
            averageSpeedMbps: avgSpeed
        )
    }
}

/// Statistics about connectivity history
public struct HistoryStatistics {
    public let totalChecks: Int
    public let onlineCount: Int
    public let offlineCount: Int
    public let averageSpeedMbps: Double?

    public var uptimePercentage: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(onlineCount) / Double(totalChecks) * 100
    }
}
