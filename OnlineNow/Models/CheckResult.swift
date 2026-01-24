//
//  CheckResult.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import Foundation

struct CheckResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let connectionType: ConnectionType
    let isOnline: Bool
    let speedMbps: Double?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), connectionType: ConnectionType, isOnline: Bool, speedMbps: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.connectionType = connectionType
        self.isOnline = isOnline
        self.speedMbps = speedMbps
    }
    
    var formattedSpeed: String {
        guard let speed = speedMbps else {
            return "N/A"
        }
        return String(format: "%.2f Mbps", speed)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var relativeTime: String {
        let interval = Date().timeIntervalSince(timestamp)
        
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
}
