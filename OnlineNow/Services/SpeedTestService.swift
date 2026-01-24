//
//  SpeedTestService.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import Foundation

class SpeedTestService: ObservableObject {
    // Test file size in bytes (512 KB for minimal data usage)
    private let testFileSize: Double = 512_000
    
    // URL for speed test - using a reliable CDN endpoint
    private let testURL = "https://httpbin.org/bytes/512000"
    
    // Speed confidence thresholds in Mbps
    private let verySlowThreshold = 1.0      // < 1 Mbps: Very slow (unusable for most tasks)
    private let slowThreshold = 5.0          // 1-5 Mbps: Slow (basic browsing only)
    private let moderateThreshold = 25.0     // 5-25 Mbps: Moderate (HD streaming, video calls)
    private let goodThreshold = 100.0        // 25-100 Mbps: Good (multiple HD streams, gaming)
                                             // > 100 Mbps: Excellent (ultra HD, heavy usage)
    
    func measureSpeed() async -> Double? {
        guard let url = URL(string: testURL) else {
            return nil
        }
        
        // Configure URLSession with explicit timeouts for better UX
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0  // 15 seconds for request timeout
        configuration.timeoutIntervalForResource = 30.0  // 30 seconds for resource timeout
        let session = URLSession(configuration: configuration)
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(from: url)
            
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
            // Note: Error is not shown to user as speed measurement failure
            // is communicated through the UI by returning nil
            return nil
        }
    }
    
    func measureSpeedWithConfidence() async -> (speed: Double?, confidence: String) {
        guard let speed = await measureSpeed() else {
            return (nil, "Unable to measure speed")
        }
        
        // Determine confidence level based on speed thresholds
        let confidence: String
        if speed < verySlowThreshold {
            confidence = "Very slow connection"
        } else if speed < slowThreshold {
            confidence = "Slow connection"
        } else if speed < moderateThreshold {
            confidence = "Moderate connection"
        } else if speed < goodThreshold {
            confidence = "Good connection"
        } else {
            confidence = "Excellent connection"
        }
        
        return (speed, confidence)
    }
}
