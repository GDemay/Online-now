//
//  SpeedTestService.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import Foundation

class SpeedTestService: ObservableObject {
    // Test file size in bytes (500 KB for minimal data usage)
    private let testFileSize: Double = 512_000
    
    // URL for speed test - using a reliable CDN endpoint
    private let testURL = "https://httpbin.org/bytes/512000"
    
    func measureSpeed() async -> Double? {
        guard let url = URL(string: testURL) else {
            return nil
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Calculate speed in Mbps
            let bytesDownloaded = Double(data.count)
            let bitsDownloaded = bytesDownloaded * 8
            let megabitsDownloaded = bitsDownloaded / 1_000_000
            let speedMbps = megabitsDownloaded / duration
            
            // Return reasonable speed (cap at 1000 Mbps to avoid outliers)
            return min(speedMbps, 1000.0)
        } catch {
            print("Speed test error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func measureSpeedWithConfidence() async -> (speed: Double?, confidence: String) {
        guard let speed = await measureSpeed() else {
            return (nil, "Unable to measure speed")
        }
        
        let confidence: String
        if speed < 1.0 {
            confidence = "Very slow connection"
        } else if speed < 5.0 {
            confidence = "Slow connection"
        } else if speed < 25.0 {
            confidence = "Moderate connection"
        } else if speed < 100.0 {
            confidence = "Good connection"
        } else {
            confidence = "Excellent connection"
        }
        
        return (speed, confidence)
    }
}
