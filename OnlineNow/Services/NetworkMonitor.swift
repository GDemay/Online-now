//
//  NetworkMonitor.swift
//  OnlineNow
//
//  Created by OnlineNow Team
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var currentConnectionType: ConnectionType = .unknown
    @Published var isConnected: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.isConnected = path.status == .satisfied
                
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.currentConnectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self.currentConnectionType = .cellular
                    } else {
                        self.currentConnectionType = .unknown
                    }
                } else {
                    self.currentConnectionType = .none
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    func checkConnection() async -> (isOnline: Bool, connectionType: ConnectionType) {
        // Perform actual internet reachability check
        let isReachable = await performReachabilityCheck()
        return (isReachable, currentConnectionType)
    }
    
    private func performReachabilityCheck() async -> Bool {
        // Test actual internet connectivity by attempting to reach a reliable endpoint
        guard let url = URL(string: "https://www.apple.com/library/test/success.html") else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let content = String(data: data, encoding: .utf8),
               content.contains("Success") {
                return true
            }
            return false
        } catch {
            return false
        }
    }
}
