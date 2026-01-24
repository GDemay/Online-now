//
//  ContentView.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var historyManager: HistoryManager
    @StateObject private var speedTestService = SpeedTestService()
    
    @State private var isChecking = false
    @State private var isMeasuringSpeed = false
    @State private var currentSpeed: Double?
    @State private var speedConfidence: String = ""
    @State private var showHistory = false
    @State private var statusMessage = "Tap to Check"
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient based on connection status
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Status Icon
                    statusIcon
                        .font(.system(size: 100))
                        .accessibilityLabel(accessibilityStatusLabel)
                    
                    // Status Text
                    VStack(spacing: 10) {
                        Text(statusTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text(statusMessage)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Speed display
                    if let speed = currentSpeed {
                        VStack(spacing: 5) {
                            Text(String(format: "%.2f Mbps", speed))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(speedConfidence)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Speed: \(String(format: "%.2f", speed)) megabits per second. \(speedConfidence)")
                    }
                    
                    // Last check info
                    if let lastCheck = historyManager.lastCheck, !isChecking {
                        VStack(spacing: 5) {
                            Text("Last checked")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(lastCheck.relativeTime)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    // Check button
                    Button(action: performCheck) {
                        HStack(spacing: 12) {
                            if isChecking || isMeasuringSpeed {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                            }
                            Text(buttonTitle)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isChecking || isMeasuringSpeed)
                    .padding(.horizontal, 40)
                    .accessibilityLabel(buttonAccessibilityLabel)
                    
                    // History button
                    Button(action: { showHistory = true }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View History")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 12)
                    }
                    .padding(.bottom, 20)
                    .accessibilityLabel("View connection history")
                }
                .padding()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showHistory) {
                HistoryView()
                    .environmentObject(historyManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        if isChecking || isMeasuringSpeed {
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        if networkMonitor.isConnected {
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var statusIcon: Image {
        if isChecking || isMeasuringSpeed {
            return Image(systemName: "wifi.circle")
        }
        
        if networkMonitor.isConnected {
            switch networkMonitor.currentConnectionType {
            case .wifi:
                return Image(systemName: "wifi.circle.fill")
            case .cellular:
                return Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
            default:
                return Image(systemName: "checkmark.circle.fill")
            }
        } else {
            return Image(systemName: "wifi.slash")
        }
    }
    
    private var statusTitle: String {
        if isChecking {
            return "Checking..."
        }
        
        if isMeasuringSpeed {
            return "Measuring..."
        }
        
        if networkMonitor.isConnected {
            return "Online"
        } else {
            return "Offline"
        }
    }
    
    private var buttonTitle: String {
        if isChecking {
            return "Checking Connection"
        }
        if isMeasuringSpeed {
            return "Measuring Speed"
        }
        return "Check Now"
    }
    
    // MARK: - Accessibility
    
    private var accessibilityStatusLabel: String {
        if isChecking {
            return "Checking connection status"
        }
        if isMeasuringSpeed {
            return "Measuring connection speed"
        }
        if networkMonitor.isConnected {
            return "Online via \(networkMonitor.currentConnectionType.rawValue)"
        }
        return "Offline, no internet connection"
    }
    
    private var buttonAccessibilityLabel: String {
        if isChecking || isMeasuringSpeed {
            return "Checking in progress"
        }
        return "Check internet connection now"
    }
    
    // MARK: - Actions
    
    private func performCheck() {
        Task {
            isChecking = true
            currentSpeed = nil
            statusMessage = "Verifying connection..."
            
            // Check connection
            let result = await networkMonitor.checkConnection()
            
            await MainActor.run {
                isChecking = false
                
                if result.isOnline {
                    statusMessage = result.connectionType.rawValue
                    
                    // Measure speed
                    Task {
                        isMeasuringSpeed = true
                        statusMessage = "Testing speed..."
                        
                        let speedResult = await speedTestService.measureSpeedWithConfidence()
                        
                        await MainActor.run {
                            isMeasuringSpeed = false
                            currentSpeed = speedResult.speed
                            speedConfidence = speedResult.confidence
                            
                            // Save to history
                            let checkResult = CheckResult(
                                connectionType: result.connectionType,
                                isOnline: result.isOnline,
                                speedMbps: speedResult.speed
                            )
                            historyManager.saveCheck(checkResult)
                            
                            statusMessage = result.connectionType.rawValue
                        }
                    }
                } else {
                    statusMessage = "No internet connection"
                    
                    // Save offline check to history
                    let checkResult = CheckResult(
                        connectionType: result.connectionType,
                        isOnline: result.isOnline,
                        speedMbps: nil
                    )
                    historyManager.saveCheck(checkResult)
                }
            }
        }
    }
}

// For Canvas Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NetworkMonitor())
            .environmentObject(HistoryManager())
    }
}
