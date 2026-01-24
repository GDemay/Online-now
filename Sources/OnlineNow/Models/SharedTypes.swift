import Foundation

/// Connection type enumeration for type safety
/// Sendable-conformant for safe use across concurrency domains
public enum ConnectionType: String, Codable, CaseIterable, Sendable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
    case none = "None"

    public var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .unknown: return "questionmark.circle"
        case .none: return "wifi.slash"
        }
    }

    public var displayName: String {
        return rawValue
    }

    /// Whether this connection type has any network interface
    public var hasInterface: Bool {
        switch self {
        case .wifi, .cellular, .ethernet:
            return true
        case .unknown, .none:
            return false
        }
    }

    /// Whether this is a wireless connection
    public var isWireless: Bool {
        switch self {
        case .wifi, .cellular:
            return true
        case .ethernet, .unknown, .none:
            return false
        }
    }
}

/// Speed categories for classifying connection quality
public enum SpeedCategory: String, Sendable {
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case acceptable = "Acceptable"
    case slow = "Slow"
    case verySlow = "Very Slow"
    case unknown = "Unknown"

    /// Suggested usage based on speed category
    public var suggestedUsage: String {
        switch self {
        case .excellent:
            return "4K streaming, large downloads, video calls"
        case .veryGood:
            return "HD streaming, video calls, gaming"
        case .good:
            return "Standard streaming, browsing, video calls"
        case .acceptable:
            return "Browsing, email, music streaming"
        case .slow:
            return "Basic browsing, text-based apps"
        case .verySlow:
            return "Limited functionality"
        case .unknown:
            return "Speed not measured"
        }
    }
}

/// Application state for connectivity monitoring
public enum AppState: String, Sendable {
    case idle = "Idle"
    case checking = "Checking"
    case measuringSpeed = "Measuring Speed"
    case online = "Online"
    case offline = "Offline"
    case limitedConnectivity = "Limited"

    /// Whether the state indicates active network availability
    public var isOnline: Bool {
        switch self {
        case .online, .limitedConnectivity:
            return true
        case .idle, .checking, .measuringSpeed, .offline:
            return false
        }
    }
}
