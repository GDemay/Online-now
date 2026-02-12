import SwiftUI

/// Contextual tip prompt shown after key moments
@available(iOS 15.0, macOS 12.0, *)
public struct TipPromptView: View {
    @Environment(\.colorScheme) private var colorScheme
    let trigger: TipPromptTrigger
    let onShowTipJar: () -> Void
    let onDismiss: () -> Void

    public init(
        trigger: TipPromptTrigger,
        onShowTipJar: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.trigger = trigger
        self.onShowTipJar = onShowTipJar
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title and message
            VStack(spacing: 8) {
                Text(trigger.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(trigger.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Buttons
            VStack(spacing: 12) {
                Button {
                    onShowTipJar()
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Support OnlineNow")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button("Maybe Later") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .padding(.horizontal, 32)
    }

    private var cardBackgroundColor: Color {
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

/// Supporter benefits and status view
@available(iOS 15.0, macOS 12.0, *)
public struct SupporterBenefitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tippingManager: TippingManager

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
                // Current status
                statusSection

                // Benefits available
                benefitsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(backgroundColor)
        .navigationTitle("Supporter Benefits")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            #endif
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 16) {
            // Badge
            if let badge = tippingManager.supporterBadge {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: tippingManager.isPowerSupporter ? "star.fill" : "heart.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(badge)
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("Not a Supporter Yet")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }

            // Total support
            if tippingManager.tipCount > 0 {
                VStack(spacing: 4) {
                    Text("Total Support")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("$\(String(format: "%.2f", tippingManager.totalTipsAmount))")
                        .font(.title.bold())
                        .foregroundStyle(.primary)

                    Text("\(tippingManager.tipCount) tip\(tippingManager.tipCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlock Benefits")
                .font(.headline)

            // List of benefits with unlock status
            BenefitCard(
                icon: "person.text.rectangle",
                title: "Name in Credits",
                description: "Your name listed in the app's credits",
                requirement: "$2+ total",
                isUnlocked: tippingManager.totalTipsAmount >= 2,
                iconColor: .green
            )

            BenefitCard(
                icon: "paintbrush.pointed.fill",
                title: "Custom App Icons",
                description: "Choose from exclusive app icon designs",
                requirement: "$5+ total",
                isUnlocked: tippingManager.isSupporter,
                iconColor: .blue
            )

            BenefitCard(
                icon: "star.fill",
                title: "Beta Feature Access",
                description: "Try new features before public release",
                requirement: "$10+ total",
                isUnlocked: tippingManager.isPowerSupporter,
                iconColor: .purple
            )

            BenefitCard(
                icon: "sparkles",
                title: "Priority Support",
                description: "Get faster responses to your questions",
                requirement: "$10+ total",
                isUnlocked: tippingManager.isPowerSupporter,
                iconColor: .orange
            )
        }
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

// MARK: - Benefit Card

@available(iOS 15.0, macOS 12.0, *)
struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    let requirement: String
    let isUnlocked: Bool
    let iconColor: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(requirement)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .green : .blue)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .opacity(isUnlocked ? 1 : 0.7)
        )
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

// MARK: - Previews

@available(iOS 15.0, macOS 12.0, *)
struct TipPromptView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            TipPromptView(
                trigger: .firstSpeedTest,
                onShowTipJar: {},
                onDismiss: {}
            )
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct SupporterBenefitsView_Previews: PreviewProvider {
    static var previews: some View {
        SupporterBenefitsView(tippingManager: TippingManager())
    }
}
