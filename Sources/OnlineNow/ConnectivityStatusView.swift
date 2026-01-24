import SwiftUI

/// A view that displays the current network connectivity status
@available(iOS 15.0, *)
public struct ConnectivityStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                statusIcon
                statusText
                connectionTypeText
            }
        }
        .onAppear {
            networkMonitor.start()
        }
        .onDisappear {
            networkMonitor.stop()
        }
    }
    
    private var backgroundColor: Color {
        networkMonitor.isConnected ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
    }
    
    private var statusIcon: some View {
        Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
            .font(.system(size: 100))
            .foregroundColor(networkMonitor.isConnected ? .green : .red)
    }
    
    private var statusText: some View {
        Text(networkMonitor.isConnected ? "Online" : "Offline")
            .font(.system(size: 48, weight: .bold))
            .foregroundColor(networkMonitor.isConnected ? .green : .red)
    }
    
    private var connectionTypeText: some View {
        Group {
            if networkMonitor.isConnected {
                Text(connectionTypeString)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var connectionTypeString: String {
        switch networkMonitor.connectionType {
        case .wifi:
            return "via WiFi"
        case .cellular:
            return "via Cellular"
        case .ethernet:
            return "via Ethernet"
        case .unknown:
            return "Connected"
        }
    }
}

@available(iOS 15.0, *)
struct ConnectivityStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectivityStatusView()
    }
}
