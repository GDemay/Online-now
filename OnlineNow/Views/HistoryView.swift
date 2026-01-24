//
//  HistoryView.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if historyManager.checkHistory.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No History Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Check your connection to start building history")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        // Summary section
                        Section {
                            let stats = historyManager.getHistoryStats()
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Total Checks")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(stats.totalChecks)")
                                        .font(.headline)
                                }
                                
                                if let avgSpeed = stats.avgSpeed {
                                    HStack {
                                        Text("Average Speed")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "%.2f Mbps", avgSpeed))
                                            .font(.headline)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        } header: {
                            Text("Summary")
                        }
                        
                        // History items
                        Section {
                            ForEach(historyManager.checkHistory) { check in
                                HistoryRowView(check: check)
                            }
                        } header: {
                            Text("Recent Checks")
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !historyManager.checkHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Text("Clear")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Clear History", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    historyManager.clearHistory()
                }
            } message: {
                Text("This will permanently delete all connection history. This action cannot be undone.")
            }
        }
    }
}

struct HistoryRowView: View {
    let check: CheckResult
    
    var body: some View {
        HStack(spacing: 15) {
            // Status icon
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(check.connectionType.rawValue)
                        .font(.headline)
                    
                    if !check.isOnline {
                        Text("• Offline")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                
                Text(check.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Speed display
            if let speed = check.speedMbps {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", speed))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Mbps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("—")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var iconName: String {
        if !check.isOnline {
            return "wifi.slash"
        }
        
        switch check.connectionType {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .none:
            return "wifi.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        if !check.isOnline {
            return .red
        }
        
        switch check.connectionType {
        case .wifi:
            return .blue
        case .cellular:
            return .green
        case .none:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var accessibilityLabel: String {
        var label = "\(check.connectionType.rawValue) connection"
        
        if !check.isOnline {
            label += ", offline"
        } else {
            label += ", online"
        }
        
        if let speed = check.speedMbps {
            label += ", speed \(String(format: "%.1f", speed)) megabits per second"
        }
        
        label += ", checked \(check.relativeTime)"
        
        return label
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = HistoryManager()
        
        // Add sample data
        manager.saveCheck(CheckResult(
            connectionType: .wifi,
            isOnline: true,
            speedMbps: 45.2
        ))
        
        return HistoryView()
            .environmentObject(manager)
    }
}
