//
//  ConnectionStatus.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import Foundation

enum ConnectionType: String, Codable {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case none = "No Connection"
    case unknown = "Unknown"
}

enum ConnectionState {
    case checking
    case online(ConnectionType)
    case offline
    case measuringSpeed
    case error(String)
}
