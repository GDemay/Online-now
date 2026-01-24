import SwiftUI
import SwiftData

@available(iOS 17.0, *)
@main
struct OnlineNowApp: App {

    /// SwiftData model container for connectivity history
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ConnectivityCheck.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ConnectivityStatusView()
        }
        .modelContainer(sharedModelContainer)
    }
}
