//
//  HistoryManager.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import Foundation
import Combine

@MainActor
class HistoryManager: ObservableObject {
    @Published var checkHistory: [CheckResult] = []
    @Published var lastCheck: CheckResult?
    
    private let saveKey = "OnlineNowHistory"
    private let maxHistoryItems = 1000
    
    init() {
        loadHistory()
    }
    
    func saveCheck(_ result: CheckResult) {
        checkHistory.insert(result, at: 0)
        lastCheck = result
        
        // Limit history size
        if checkHistory.count > maxHistoryItems {
            checkHistory = Array(checkHistory.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func clearHistory() {
        checkHistory.removeAll()
        lastCheck = nil
        saveHistory()
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(checkHistory)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to save history: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            checkHistory = try decoder.decode([CheckResult].self, from: data)
            lastCheck = checkHistory.first
        } catch {
            print("Failed to load history: \(error.localizedDescription)")
        }
    }
    
    func getHistoryStats() -> (totalChecks: Int, avgSpeed: Double?, lastOnline: Date?) {
        let totalChecks = checkHistory.count
        
        let speedsOnly = checkHistory.compactMap { $0.speedMbps }
        let avgSpeed = speedsOnly.isEmpty ? nil : speedsOnly.reduce(0, +) / Double(speedsOnly.count)
        
        let lastOnline = checkHistory.first(where: { $0.isOnline })?.timestamp
        
        return (totalChecks, avgSpeed, lastOnline)
    }
}
