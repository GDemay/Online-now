import SwiftUI
import OnlineNow

@main
struct OnlineNowApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectivityStatusView()
        }
    }
}
