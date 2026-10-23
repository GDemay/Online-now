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

    private var purchasesEnabled: Bool {
        #if DEBUG
        // Keep the disabled-purchase SDK regressions isolated to XCTest.
        // The shipping app always enables the tip jar, without an argument override.
        let arguments = ProcessInfo.processInfo.arguments
        return !(arguments.contains("--ui-testing")
            && arguments.contains("--purchases-disabled-ui-fixture"))
        #else
        return true
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if isUnitTestHost {
                // Hosted unit tests create their own services. A live app listener
                // could otherwise finish StoreKit transactions before a test sees them.
                Color.clear
            } else if let container = storage.container {
                ConnectivityStatusView(purchasesEnabled: purchasesEnabled, tipPromptsEnabled: false)
                    .modelContainer(container)
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
                        .foregroundStyle(Color.primary.opacity(0.75))
                } actions: {
                    Button("Try Again") { storage = HistoryStorage.open() }
                        .buttonStyle(OnlineNowPrimaryButtonStyle())
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
            return HistoryStorage(
                container: try? ModelContainer(for: schema, configurations: [
                    ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                ]), isTemporary: false
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
