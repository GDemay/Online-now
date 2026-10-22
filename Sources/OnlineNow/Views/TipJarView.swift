import StoreKit
import SwiftUI

/// Optional tips never gate an app feature or start a subscription.
@available(iOS 15.0, macOS 12.0, *)
public struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                            .foregroundStyle(Color.primary.opacity(0.75))
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
                                .foregroundStyle(Color.primary.opacity(0.75))
                            Text("Consumable tips cannot be restored after reinstalling the app.")
                                .font(.caption)
                                .foregroundStyle(Color.primary.opacity(0.75))
                        }
                        .multilineTextAlignment(.center)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("tipJar.support")
                        .accessibilityValue("\(tippingManager.tipCount)")
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
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("tipJar.pending")
            }

            if tippingManager.isLoading {
                ProgressView {
                    Text("Connecting to the App Store…")
                        .foregroundStyle(Color.primary.opacity(0.75))
                }
                    .padding()
                    .accessibilityIdentifier("tipJar.loading")
            } else if tippingManager.products.isEmpty {
                Text("Tips are unavailable right now")
                    .font(.headline)
                    .accessibilityIdentifier("tipJar.unavailable")
                Text(tippingManager.errorMessage ?? "Check your connection and try again. All app features remain free.")
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .multilineTextAlignment(.center)
                retryButton
            } else {
                ForEach(tippingManager.products, id: \.id) { product in
                    if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
                        TipPurchaseContext { purchaseAction in
                            tipOption(for: product) { try await purchaseAction($0) }
                        }
                    } else {
                        // Preserve the library's iOS 15/macOS 12 availability.
                        tipOption(for: product) { try await $0.purchase() }
                    }
                }
                if let message = tippingManager.errorMessage {
                    Text(message)
                        .foregroundStyle(OnlineNowColors.errorText(in: colorScheme))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("tipJar.error")
                        #if DEBUG
                        .accessibilityValue(tippingManager.visualReviewErrorDiagnostics ?? "")
                        #endif
                }
            }
        }
    }

    private func tipOption(
        for product: Product,
        performPurchase: @escaping @MainActor (Product) async throws -> Product.PurchaseResult
    ) -> some View {
        TipOptionCard(
            product: product,
            isPurchasing: tippingManager.isPurchasing && selectedProductID == product.id
        ) {
            selectedProductID = product.id
            Task { @MainActor in
                if await tippingManager.purchase(product, performPurchase: performPurchase) {
                    showThankYou = true
                }
            }
        }
        .disabled(tippingManager.isPurchasing || tippingManager.isPending)
    }

    private var retryButton: some View {
        Button {
            Task { await tippingManager.loadProducts() }
        } label: {
            Label("Try again", systemImage: "arrow.clockwise")
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("tipJar.retry")
    }
}

/// Read the action inside the presenting SwiftUI hierarchy so StoreKit receives
/// the correct scene for its payment confirmation UI. Never store it in a model.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
private struct TipPurchaseContext<Content: View>: View {
    @Environment(\.purchase) private var purchaseAction
    let content: (PurchaseAction) -> Content

    init(content: @escaping (PurchaseAction) -> Content) {
        self.content = content
    }

    var body: some View { content(purchaseAction) }
}

@available(iOS 15.0, macOS 12.0, *)
private struct TipOptionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let product: Product
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 16) {
                        productDescription
                        purchasePrice
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 12) {
                        productDescription
                        Spacer(minLength: 8)
                        purchasePrice
                    }
                }
            }
            .padding(18)
            .foregroundStyle(.white)
            .background(OnlineNowColors.actionFill)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send a one-time tip of \(product.displayPrice)")
        .accessibilityValue(isPurchasing ? "Purchase in progress" : "")
        .accessibilityIdentifier("tipJar.purchase")
    }

    private var productDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.displayName)
                .font(.headline)
            Text("One-time tip")
                .font(.subheadline)
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var purchasePrice: some View {
        if isPurchasing {
            ProgressView()
                .tint(.white)
        } else {
            Text(product.displayPrice)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ImpactRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: String
    let text: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    impactIcon
                    impactText
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    impactIcon.frame(width: 22)
                    impactText
                }
            }
        }
    }

    private var impactIcon: some View {
        Image(systemName: icon)
            .foregroundStyle(.blue)
            .accessibilityHidden(true)
    }

    private var impactText: some View {
        Text(text)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
    }
}
