import Foundation
#if os(macOS)
import AppKit
#endif

/// Service for validating network measurements against system tools
/// Provides comparison between app measurements and terminal-based tools
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor DiagnosticService {
    
    private let latencyService: LatencyMeasurementService
    private let speedTestService: SpeedTestService
    
    public init() {
        self.latencyService = LatencyMeasurementService()
        self.speedTestService = SpeedTestService()
    }
    
    // MARK: - Latency Diagnostics
    
    /// Compares app latency measurements with system ping (macOS only)
    /// - Parameter host: Host to ping (default: 1.1.1.1)
    /// - Returns: DiagnosticResult comparing app vs system measurements
    public func validateLatency(host: String = "1.1.1.1") async -> DiagnosticResult {
        // Measure with app
        let appResult = await latencyService.measureAverageLatency(samples: 3)
        
        #if os(macOS)
        // Measure with system ping
        let pingResult = await runSystemPing(host: host, count: 3)
        
        return DiagnosticResult(
            testType: .latency,
            appMeasurement: appResult.rttMs.map { "\($0) ms" } ?? "Failed",
            systemMeasurement: pingResult.averageMs.map { String(format: "%.1f ms", $0) } ?? "Failed",
            difference: calculateDifference(app: appResult.rttMs, system: pingResult.averageMs),
            appMethod: appResult.method.rawValue,
            systemMethod: "ICMP ping",
            details: [
                "App Endpoint": appResult.endpoint,
                "App Error": appResult.error ?? "None",
                "Ping Output": pingResult.rawOutput ?? "N/A",
                "Ping Error": pingResult.error ?? "None"
            ],
            isValid: isLatencyValid(app: appResult.rttMs, system: pingResult.averageMs)
        )
        #else
        // iOS/watchOS - no system ping available
        return DiagnosticResult(
            testType: .latency,
            appMeasurement: appResult.rttMs.map { String(format: "%.1f ms", $0) } ?? "Failed",
            systemMeasurement: "Not available on iOS/watchOS",
            difference: nil,
            appMethod: appResult.method.rawValue,
            systemMethod: "N/A",
            details: [
                "App Endpoint": appResult.endpoint,
                "App Error": appResult.error ?? "None",
                "Note": "System ping requires macOS"
            ],
            isValid: true  // Can't validate without system tool
        )
        #endif
    }
    
    /// Runs comprehensive diagnostic check
    /// - Returns: Array of diagnostic results for different measurements
    public func runFullDiagnostics() async -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []
        
        // Test latency against multiple endpoints
        let endpoints = ["1.1.1.1", "8.8.8.8", "www.google.com"]
        for endpoint in endpoints {
            let result = await validateLatency(host: endpoint)
            results.append(result)
        }
        
        // Test speed measurement
        let speedDiagnostic = await validateSpeedTest()
        results.append(speedDiagnostic)
        
        return results
    }
    
    /// Validates speed test measurements
    /// - Returns: DiagnosticResult for speed test
    public func validateSpeedTest() async -> DiagnosticResult {
        let appResult = await speedTestService.measureSpeed(quick: true)
        
        let appSpeed = appResult.speedMbps.map { String(format: "%.1f Mbps", $0) } ?? "Failed"
        
        #if os(macOS)
        // On macOS, suggest comparison with speedtest-cli
        return DiagnosticResult(
            testType: .speed,
            appMeasurement: appSpeed,
            systemMeasurement: "Run 'speedtest-cli' manually to compare",
            difference: nil,
            appMethod: "HTTPS download",
            systemMethod: "speedtest-cli",
            details: [
                "Bytes Downloaded": String(appResult.bytesDownloaded),
                "Duration": String(format: "%.2f seconds", appResult.durationSeconds),
                "Error": appResult.error ?? "None",
                "Install speedtest-cli": "brew install speedtest-cli",
                "Run test": "speedtest-cli --simple"
            ],
            isValid: appResult.speedMbps != nil
        )
        #else
        return DiagnosticResult(
            testType: .speed,
            appMeasurement: appSpeed,
            systemMeasurement: "Not available on iOS/watchOS",
            difference: nil,
            appMethod: "HTTPS download",
            systemMethod: "N/A",
            details: [
                "Bytes Downloaded": String(appResult.bytesDownloaded),
                "Duration": String(format: "%.2f seconds", appResult.durationSeconds),
                "Error": appResult.error ?? "None"
            ],
            isValid: appResult.speedMbps != nil
        )
        #endif
    }
    
    // MARK: - Private Helpers
    
    private func calculateDifference(app: Double?, system: Double?) -> String? {
        guard let app = app, let system = system else { return nil }
        let diff = abs(app - system)
        let percentDiff = (diff / system) * 100
        return String(format: "%.1f ms (%.0f%%)", diff, percentDiff)
    }
    
    private func isLatencyValid(app: Double?, system: Double?) -> Bool {
        guard let app = app, let system = system else { return false }
        let percentDiff = abs(app - system) / system * 100
        // Consider valid if within 30% (TCP vs ICMP have different characteristics)
        return percentDiff < 30
    }
    
    #if os(macOS)
    /// Runs system ping command and parses results (macOS only)
    /// - Parameters:
    ///   - host: Host to ping
    ///   - count: Number of pings
    /// - Returns: PingResult with parsed statistics
    private func runSystemPing(host: String, count: Int) async -> PingResult {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "\(count)", host]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return PingResult(averageMs: nil, rawOutput: nil, error: "Failed to read output")
            }
            
            // Parse ping output for average RTT
            // Example: "round-trip min/avg/max/stddev = 10.123/15.456/20.789/3.456 ms"
            let avgPattern = #"round-trip.*?= [\d.]+/([\d.]+)/"#
            if let range = output.range(of: avgPattern, options: .regularExpression) {
                let match = String(output[range])
                if let avgMatch = match.range(of: #"/([\d.]+)/"#, options: .regularExpression) {
                    let avgStr = match[avgMatch].dropFirst().dropLast()
                    if let avg = Double(avgStr) {
                        return PingResult(averageMs: avg, rawOutput: output, error: nil)
                    }
                }
            }
            
            return PingResult(averageMs: nil, rawOutput: output, error: "Failed to parse ping output")
            
        } catch {
            return PingResult(averageMs: nil, rawOutput: nil, error: error.localizedDescription)
        }
    }
    
    /// Result from system ping command
    private struct PingResult {
        let averageMs: Double?
        let rawOutput: String?
        let error: String?
    }
    #endif
}

// MARK: - Result Types

/// Result of a diagnostic comparison
public struct DiagnosticResult: Sendable {
    /// Type of test performed
    public let testType: DiagnosticTestType
    
    /// Measurement from app
    public let appMeasurement: String
    
    /// Measurement from system tool
    public let systemMeasurement: String
    
    /// Difference between measurements
    public let difference: String?
    
    /// Method used by app
    public let appMethod: String
    
    /// Method used by system tool
    public let systemMethod: String
    
    /// Additional details about the test
    public let details: [String: String]
    
    /// Whether the app measurement is considered valid
    public let isValid: Bool
    
    /// Status emoji for quick visual feedback
    public var statusEmoji: String {
        if systemMeasurement.contains("Not available") {
            return "ℹ️"
        }
        return isValid ? "✅" : "⚠️"
    }
    
    /// Formatted summary string
    public var summary: String {
        var text = "\(statusEmoji) \(testType.rawValue) Test\n"
        text += "App: \(appMeasurement) (\(appMethod))\n"
        text += "System: \(systemMeasurement) (\(systemMethod))\n"
        if let diff = difference {
            text += "Difference: \(diff)\n"
        }
        return text
    }
    
    public init(
        testType: DiagnosticTestType,
        appMeasurement: String,
        systemMeasurement: String,
        difference: String?,
        appMethod: String,
        systemMethod: String,
        details: [String: String],
        isValid: Bool
    ) {
        self.testType = testType
        self.appMeasurement = appMeasurement
        self.systemMeasurement = systemMeasurement
        self.difference = difference
        self.appMethod = appMethod
        self.systemMethod = systemMethod
        self.details = details
        self.isValid = isValid
    }
}

/// Type of diagnostic test
public enum DiagnosticTestType: String, Sendable {
    case latency = "Latency"
    case speed = "Speed"
    case reachability = "Reachability"
}
