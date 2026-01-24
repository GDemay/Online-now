import SwiftUI
import OnlineNow

/// Example: Using NetworkMonitor in a custom view
struct CustomConnectivityView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Connection Status")
                .font(.largeTitle)
                .padding()
            
            HStack {
                Circle()
                    .fill(networkMonitor.isConnected ? Color.green : Color.red)
                    .frame(width: 20, height: 20)
                
                Text(networkMonitor.isConnected ? "Connected" : "Disconnected")
                    .font(.title2)
            }
            
            if networkMonitor.isConnected {
                Text("Connection Type: \(connectionTypeText)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            networkMonitor.start()
        }
        .onDisappear {
            networkMonitor.stop()
        }
    }
    
    private var connectionTypeText: String {
        switch networkMonitor.connectionType {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}

/// Example: Using NetworkMonitor with UIKit
import UIKit
import Combine

class ConnectivityViewController: UIViewController {
    private let networkMonitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNetworkMonitoring()
        networkMonitor.start()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.updateUI(isConnected: isConnected)
            }
            .store(in: &cancellables)
    }
    
    private func updateUI(isConnected: Bool) {
        statusLabel.text = isConnected ? "Online" : "Offline"
        statusLabel.textColor = isConnected ? .systemGreen : .systemRed
        view.backgroundColor = isConnected ? 
            UIColor.systemGreen.withAlphaComponent(0.1) : 
            UIColor.systemRed.withAlphaComponent(0.1)
    }
    
    deinit {
        networkMonitor.stop()
    }
}
