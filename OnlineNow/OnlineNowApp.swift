//
//  OnlineNowApp.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import SwiftUI

@main
struct OnlineNowApp: App {
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var historyManager = HistoryManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkMonitor)
                .environmentObject(historyManager)
        }
    }
}
