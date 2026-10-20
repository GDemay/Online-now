import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
public struct TipPromptView: View {
    let trigger: TipPromptTrigger
    let onShowTipJar: () -> Void
    let onDismiss: () -> Void

    public init(trigger: TipPromptTrigger, onShowTipJar: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.trigger = trigger
        self.onShowTipJar = onShowTipJar
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text(trigger.title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Text(trigger.message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onShowTipJar) {
                Text("Open tip jar")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("tipPrompt.open")
            Button("Not now", action: onDismiss)
                .frame(minHeight: 44)
                .accessibilityIdentifier("tipPrompt.dismiss")
        }
        .padding(24)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .padding(.horizontal, 24)
    }
}

/// Kept under its original public name for callers. Tips are gratitude, not an
/// entitlement to unimplemented icons, beta access, credits, or priority support.
@available(iOS 15.0, macOS 12.0, *)
public struct SupporterBenefitsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tippingManager: TippingManager

    public init(tippingManager: TippingManager) {
        self.tippingManager = tippingManager
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text(tippingManager.isSupporter ? "Thank you for your support" : "Every feature is free")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    if tippingManager.tipCount > 0 {
                        Text("\(tippingManager.tipCount) tip\(tippingManager.tipCount == 1 ? "" : "s") recorded on this device")
                    }
                    Text("Tips help maintain Online Now. They are entirely optional and do not unlock additional features or services.")
                        .foregroundStyle(.secondary)
                    Text("Tip history is saved on this device. Consumable tips cannot be restored after reinstalling the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Your support")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
}
