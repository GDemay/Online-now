import StoreKit
import SwiftUI

/// Optional tips never gate an app feature or start a subscription.
@available(iOS 15.0, macOS 12.0, *)
public struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tippingManager: TippingManager
    @State private var selectedProductID: String?
    @State private var showThankYou = false

    public init(tippingManager: TippingManager) {
        self.tippingManager = tippingManager
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("Support Online Now")
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("An optional tip helps keep the app maintained. Every feature stays free, whether you tip or not.")
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 12) {
                        ImpactRow(icon: "hammer.fill", text: "Support maintenance and bug fixes")
                        ImpactRow(icon: "checkmark.circle", text: "A one-time purchase, with no subscription")
                        ImpactRow(icon: "lock.shield", text: "Payment is handled securely by the App Store")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    purchaseSection

                    if tippingManager.tipCount > 0 {
                        VStack(spacing: 8) {
                            Label("Thank you for your support", systemImage: "heart.fill")
                                .font(.headline)
                            Text("\(tippingManager.tipCount) tip\(tippingManager.tipCount == 1 ? "" : "s") recorded on this device")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Consumable tips cannot be restored after reinstalling the app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Tip jar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("tipJar.close")
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                #endif
            }
            .alert("Thank you!", isPresented: $showThankYou) {
                Button("Done", role: .cancel) {}
            } message: {
                Text(tippingManager.impactMessage)
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .task {
            if tippingManager.products.isEmpty { await tippingManager.loadProducts() }
        }
        .accessibilityIdentifier("tipJar.screen")
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            if tippingManager.isPending {
                Label("Waiting for approval", systemImage: "clock")
                    .font(.headline)
                Text("The App Store is waiting for approval. Your support will appear here when the purchase is confirmed.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("tipJar.pending")
            }

            if tippingManager.isLoading {
                ProgressView("Connecting to the App Store…")
                    .padding()
                    .accessibilityIdentifier("tipJar.loading")
            } else if tippingManager.products.isEmpty {
                Text("Tips are unavailable right now")
                    .font(.headline)
                    .accessibilityIdentifier("tipJar.unavailable")
                Text(tippingManager.errorMessage ?? "Check your connection and try again. All app features remain free.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                retryButton
            } else {
                ForEach(tippingManager.products, id: \.id) { product in
                    TipOptionCard(
                        product: product,
                        isPurchasing: tippingManager.isPurchasing && selectedProductID == product.id
                    ) {
                        selectedProductID = product.id
                        Task {
                            if await tippingManager.purchase(product) { showThankYou = true }
                        }
                    }
                    .disabled(tippingManager.isPurchasing || tippingManager.isPending)
                }
                if let message = tippingManager.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("tipJar.error")
                }
            }
        }
    }

    private var retryButton: some View {
        Button {
            Task { await tippingManager.loadProducts() }
        } label: {
            Label("Try again", systemImage: "arrow.clockwise")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("tipJar.retry")
    }
}

@available(iOS 15.0, macOS 12.0, *)
private struct TipOptionCard: View {
    let product: Product
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    Text("One-time tip")
                        .font(.subheadline)
                }
                Spacer(minLength: 8)
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                }
            }
            .padding(18)
            .foregroundStyle(.white)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send a one-time tip of \(product.displayPrice)")
        .accessibilityValue(isPurchasing ? "Purchase in progress" : "")
        .accessibilityIdentifier("tipJar.purchase")
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ImpactRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
