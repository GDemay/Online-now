import StoreKit
import SwiftUI

/// Beautiful tip jar view for supporting the developer
@available(iOS 15.0, macOS 12.0, *)
public struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tippingManager: TippingManager

    @State private var selectedProduct: Product?
    @State private var showThankYou = false
    @State private var purchaseSuccess = false

    public init(tippingManager: TippingManager) {
        self.tippingManager = tippingManager
    }

    public var body: some View {
        #if os(macOS)
            NavigationView {
                scrollContent
            }
        #else
            NavigationStack {
                scrollContent
            }
        #endif
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon
                headerSection

                // Impact message
                impactSection

                // Tip options
                if tippingManager.isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else {
                    tipOptionsSection
                }

                // Total support
                if tippingManager.tipCount > 0 {
                    totalSupportSection
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(backgroundColor)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            #endif
        }
        .alert("Thank You! 💙", isPresented: $showThankYou) {
            Button("Continue") {
                if purchaseSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(tippingManager.impactMessage)
        }
        .alert("Error", isPresented: .constant(tippingManager.errorMessage != nil)) {
            Button("OK") {
                tippingManager.errorMessage = nil
            }
        } message: {
            if let error = tippingManager.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Coffee icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Support OnlineNow")
                .font(.title.bold())

            Text(
                "Buy me a coffee! Your support helps keep development going. No benefits, just gratitude!"
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Impact Section

    private var impactSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("Your Support Helps")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ImpactRow(icon: "hammer.fill", text: "Keep the app maintained")
                ImpactRow(icon: "sparkles", text: "Inspire future development")
                ImpactRow(icon: "cup.and.saucer.fill", text: "Buy me a coffee")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Tip Options

    private var tipOptionsSection: some View {
        VStack(spacing: 12) {
            ForEach(tippingManager.products, id: \.id) { product in
                TipOptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isPurchasing: tippingManager.isPurchasing && selectedProduct?.id == product.id
                ) {
                    selectedProduct = product
                    Task {
                        let success = await tippingManager.purchase(product)
                        purchaseSuccess = success
                        if success {
                            showThankYou = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Total Support

    private var totalSupportSection: some View {
        VStack(spacing: 8) {
            Text("Your Total Donations")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("$\(String(format: "%.2f", tippingManager.totalTipsAmount))")
                .font(.title2.bold())
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Thank you so much for your support! 💙")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Styling

    private var backgroundColor: some View {
        #if os(macOS)
            colorScheme == .dark
                ? Color(nsColor: .windowBackgroundColor)
                : Color(nsColor: .underPageBackgroundColor)
        #else
            colorScheme == .dark
                ? Color(uiColor: .systemBackground)
                : Color(uiColor: .systemGroupedBackground)
        #endif
    }

    private var cardBackground: some View {
        #if os(macOS)
            colorScheme == .dark
                ? Color(nsColor: .controlBackgroundColor)
                : Color(nsColor: .windowBackgroundColor)
        #else
            colorScheme == .dark
                ? Color(uiColor: .secondarySystemGroupedBackground)
                : Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - Supporting Views

@available(iOS 15.0, macOS 12.0, *)
struct TipOptionCard: View {
    let product: Product
    let isSelected: Bool
    let isPurchasing: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: isSelected ? [.blue, .purple] : [.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
            colorScheme == .dark
                ? Color(nsColor: .controlBackgroundColor)
                : Color(nsColor: .windowBackgroundColor)
        #else
            Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ImpactRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct TipJarView_Previews: PreviewProvider {
    static var previews: some View {
        TipJarView(tippingManager: TippingManager())
    }
}
