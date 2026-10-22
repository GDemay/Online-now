import SwiftUI
import SwiftData

@available(iOS 17.0, *)
@main
@MainActor
struct OnlineNowApp: App {
    @State private var storage = HistoryStorage.open()

    private var isUnitTestHost: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--unit-testing")
        #else
        return false
        #endif
    }

    private var visualReviewColorScheme: ColorScheme? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing"), args.contains("--visual-review"), args.contains("--dark-mode") {
            return .dark
        }
        #endif
        return nil
    }

    var body: some Scene {
        WindowGroup {
            if isUnitTestHost {
                // Hosted unit tests create their own services. A live app listener
                // could otherwise finish StoreKit transactions before a test sees them.
                Color.clear
            } else if let container = storage.container {
                ConnectivityStatusView()
                    .modelContainer(container)
                    .preferredColorScheme(visualReviewColorScheme)
                    .safeAreaInset(edge: .bottom) {
                        if storage.isTemporary {
                            VStack(spacing: 4) {
                                Text("History is temporarily unavailable")
                                    .font(.subheadline.bold())
                                Text("Checks still work. New history lasts for this session; existing history has been kept.")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.regularMaterial)
                            .accessibilityElement(children: .combine)
                        }
                    }
            } else {
                ContentUnavailableView {
                    Label("Unable to open history", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved history has been kept. Try opening the app again.")
                } actions: {
                    Button("Try Again") { storage = HistoryStorage.open() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
@MainActor
private struct HistoryStorage {
    let container: ModelContainer?
    let isTemporary: Bool

    static func open() -> HistoryStorage {
        let schema = Schema([ConnectivityCheck.self])
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.arguments.contains("--unit-testing") {
            let args = ProcessInfo.processInfo.arguments
            let isVisualReview = args.contains("--ui-testing") && args.contains("--visual-review")
            if isVisualReview, args.contains("--history-open-failure") {
                return HistoryStorage(container: nil, isTemporary: false)
            }
            let container = try? ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            ])
            if isVisualReview, args.contains("--seed-history"), let container {
                let context = ModelContext(container)
                let reference = Date()
                for index in 0..<6 {
                    let connected = index != 2
                    let reachable = connected && index != 1
                    let speed: Double? = reachable ? [72.0, 48.5, 12.2, 4.8][index % 4] : nil
                    context.insert(ConnectivityCheck(
                        timestamp: reference.addingTimeInterval(-Double(index + 1) * 90),
                        isConnected: connected,
                        connectionType: !connected ? "None" : (index == 3 ? "Cellular" : "WiFi"),
                        isReachable: reachable, speedMbps: speed,
                        rttMs: reachable ? Double(18 + index * 9) : nil,
                        responseTimeMs: reachable ? Double(35 + index * 15) : nil,
                        isVPNActive: index == 4,
                        errorMessage: index == 1 ? "Internet unreachable" : nil
                    ))
                }
                try? context.save()
            }
            return HistoryStorage(
                container: container,
                isTemporary: isVisualReview && args.contains("--temporary-history")
            )
        }
        #endif
        do {
            let container = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            ])
            return HistoryStorage(container: container, isTemporary: false)
        } catch {
            // Never erase an unreadable user store. Keep checking the connection using session-only history.
            let temporary = try? ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            ])
            return HistoryStorage(container: temporary, isTemporary: true)
        }
    }
}
