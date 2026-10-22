import Combine
import Foundation
import SwiftData

/// A bounded local history. Statistics and exports include all retained records.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class HistoryManager: ObservableObject {
    private let maxHistoryCount = 100
    private var modelContext: ModelContext?
    @Published public private(set) var recentChecks: [ConnectivityCheck] = []
    @Published public private(set) var lastCheck: ConnectivityCheck?
    @Published public private(set) var errorMessage: String?

    public init() {}

    public func configure(with context: ModelContext) {
        modelContext = context
        fetchRecentChecks()
    }

    public func saveCheck(_ check: ConnectivityCheck) {
        guard let context = modelContext else { return }
        context.insert(check)
        do {
            var descriptor = FetchDescriptor<ConnectivityCheck>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchOffset = maxHistoryCount
            for oldCheck in try context.fetch(descriptor) { context.delete(oldCheck) }
            try context.save()
            errorMessage = nil
            fetchRecentChecks()
        } catch {
            context.rollback()
            errorMessage = "Could not save this check. \(error.localizedDescription)"
        }
    }

    public func recordCheck(
        isConnected: Bool,
        connectionType: ConnectionType,
        isReachable: Bool,
        speedMbps: Double? = nil,
        rttMs: Double? = nil,
        responseTimeMs: Double? = nil,
        latencyMs: Double? = nil,
        isVPNActive: Bool = false,
        errorMessage: String? = nil
    ) {
        saveCheck(ConnectivityCheck(
            isConnected: isConnected, connectionType: connectionType.rawValue,
            isReachable: isReachable, speedMbps: speedMbps,
            rttMs: rttMs, responseTimeMs: responseTimeMs,
            latencyMs: latencyMs ?? rttMs ?? responseTimeMs,
            measurementMethod: rttMs != nil ? "TCP" : (responseTimeMs != nil ? "HTTP" : nil),
            isVPNActive: isVPNActive, errorMessage: errorMessage
        ))
    }

    public func fetchRecentChecks(limit: Int = 20) {
        guard let context = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<ConnectivityCheck>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = max(1, min(limit, maxHistoryCount))
            recentChecks = try context.fetch(descriptor)
            lastCheck = recentChecks.first
            errorMessage = nil
        } catch {
            errorMessage = "Could not load history. \(error.localizedDescription)"
        }
    }

    public func fetchChecks(from startDate: Date, to endDate: Date) -> [ConnectivityCheck] {
        guard let context = modelContext, startDate <= endDate else { return [] }
        do {
            let predicate = #Predicate<ConnectivityCheck> {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            }
            let descriptor = FetchDescriptor<ConnectivityCheck>(
                predicate: predicate, sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let checks = try context.fetch(descriptor)
            errorMessage = nil
            return checks
        } catch {
            errorMessage = "Could not load history. \(error.localizedDescription)"
            return []
        }
    }

    public func timeSinceLastCheck() -> String? {
        guard let lastCheck else { return nil }
        let interval = max(0, Date().timeIntervalSince(lastCheck.timestamp))
        if interval < 60 { return "Just now" }
        let value: Int
        let unit: String
        if interval < 3600 { value = Int(interval / 60); unit = "minute" }
        else if interval < 86400 { value = Int(interval / 3600); unit = "hour" }
        else { value = Int(interval / 86400); unit = "day" }
        return "\(value) \(unit)\(value == 1 ? "" : "s") ago"
    }

    @discardableResult
    public func clearHistory() -> Bool {
        guard let context = modelContext else { return false }
        do {
            for check in try allChecks() { context.delete(check) }
            try context.save()
            recentChecks = []
            lastCheck = nil
            errorMessage = nil
            return true
        } catch {
            context.rollback()
            errorMessage = "Could not clear history. \(error.localizedDescription)"
            return false
        }
    }

    private func allChecks() throws -> [ConnectivityCheck] {
        guard let context = modelContext else { throw HistoryError.notConfigured }
        return try context.fetch(FetchDescriptor<ConnectivityCheck>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))
    }

    /// RFC 4180 escaping, ISO-8601 dates, and stable numeric units for sharing diagnostics.
    public func exportCSV() throws -> String {
        let checks: [ConnectivityCheck]
        do { checks = try allChecks() }
        catch {
            errorMessage = "Could not export history. \(error.localizedDescription)"
            throw error
        }
        let dateFormatter = ISO8601DateFormatter()
        func number(_ value: Double?) -> String {
            guard let value, value.isFinite else { return "" }
            return String(value)
        }
        func escaped(_ value: String) -> String {
            // Prevent formula evaluation when imported into spreadsheet software.
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: value.hasPrefix)
                ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let header = "timestamp,status,connection_type,speed_mbps,tcp_rtt_ms,http_response_ms,vpn_detected,error"
        let rows = checks.map { check in
            let status = !check.isConnected ? "offline" : (check.isReachable ? "online" : "limited")
            return [dateFormatter.string(from: check.timestamp), status, check.connectionType,
                    number(check.speedMbps), number(check.rttMs), number(check.responseTimeMs),
                    String(check.isVPNActive), check.errorMessage ?? ""]
                .map(escaped).joined(separator: ",")
        }
        errorMessage = nil
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }

    public func getStatistics() -> HistoryStatistics {
        let checks: [ConnectivityCheck]
        do { checks = try allChecks() }
        catch {
            errorMessage = "Could not calculate history statistics. \(error.localizedDescription)"
            return HistoryStatistics(totalChecks: 0, onlineCount: 0, offlineCount: 0,
                                     limitedCount: 0, averageSpeedMbps: nil)
        }
        let speeds = checks.compactMap(\.speedMbps).filter { $0.isFinite && $0 >= 0 }
        return HistoryStatistics(
            totalChecks: checks.count,
            onlineCount: checks.filter { $0.isConnected && $0.isReachable }.count,
            offlineCount: checks.filter { !$0.isConnected }.count,
            limitedCount: checks.filter { $0.isConnected && !$0.isReachable }.count,
            averageSpeedMbps: speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)
        )
    }
}

public enum HistoryError: LocalizedError {
    case notConfigured
    public var errorDescription: String? { "History storage is not available." }
}

public struct HistoryStatistics {
    public let totalChecks: Int
    public let onlineCount: Int
    public let offlineCount: Int
    public let limitedCount: Int
    public let averageSpeedMbps: Double?

    /// Percentage of successful samples, not a claim about uninterrupted elapsed uptime.
    public var uptimePercentage: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(onlineCount) / Double(totalChecks) * 100
    }
}
