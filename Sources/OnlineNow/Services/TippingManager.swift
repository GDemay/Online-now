import Foundation
import StoreKit

/// Manages tipping functionality using StoreKit 2
/// Tracks supporter status and handles in-app purchases
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public final class TippingManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var products: [Product] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var isPurchasing = false

    // Supporter status
    @Published public var totalTipsAmount: Double = 0
    @Published public var tipCount: Int = 0
    @Published public var isSupporter: Bool = false  // $5+ total
    @Published public var isPowerSupporter: Bool = false  // $10+ total

    // Tip prompts tracking
    @Published public var shouldShowTipPrompt = false
    @Published public var tipPromptTrigger: TipPromptTrigger?

    // MARK: - Product IDs

    private let productIDs: [String] = [
        "com.gdemay.onlinenow.tip.small",  // $2
        "com.gdemay.onlinenow.tip.medium",  // $5
        "com.gdemay.onlinenow.tip.large",  // $10
    ]

    // MARK: - UserDefaults Keys

    private let totalTipsKey = "onlinenow.totalTips"
    private let tipCountKey = "onlinenow.tipCount"
    private let firstSpeedTestKey = "onlinenow.firstSpeedTest"
    private let speedTestCountKey = "onlinenow.speedTestCount"
    private let historyExportCountKey = "onlinenow.historyExportCount"
    private let lastTipPromptKey = "onlinenow.lastTipPrompt"

    // MARK: - Transaction Listener

    private var transactionListener: Task<Void, Error>?

    // MARK: - Initialization

    public init() {
        // Load saved supporter status
        loadSupporterStatus()

        // Start transaction listener
        transactionListener = listenForTransactions()

        // Load products
        Task {
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    /// Load tip products from App Store
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedProducts = try await Product.products(for: productIDs)
            products = loadedProducts.sorted { $0.price < $1.price }
            isLoading = false
        } catch {
            errorMessage = "Failed to load tip options: \(error.localizedDescription)"
            isLoading = false
            print("❌ TippingManager: Failed to load products - \(error)")
        }
    }

    // MARK: - Purchase

    /// Purchase a tip product
    public func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update supporter status
                await recordTip(amount: product.price)

                // Finish the transaction
                await transaction.finish()

                return true

            case .userCancelled:
                return false

            case .pending:
                errorMessage = "Purchase is pending approval"
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ TippingManager: Purchase failed - \(error)")
            return false
        }
    }

    /// Check transaction verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TippingError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                do {
                    // Check verification in detached context
                    let transaction: Transaction
                    switch result {
                    case .unverified:
                        throw TippingError.failedVerification
                    case .verified(let safe):
                        transaction = safe
                    }

                    // Update supporter status on main actor
                    let amount = transaction.price ?? 0
                    await self.recordTip(amount: amount)

                    await transaction.finish()
                } catch {
                    print("❌ TippingManager: Transaction update failed - \(error)")
                }
            }
        }
    }

    // MARK: - Supporter Status

    /// Record a tip and update supporter status
    private func recordTip(amount: Decimal) async {
        let doubleAmount = NSDecimalNumber(decimal: amount).doubleValue

        totalTipsAmount += doubleAmount
        tipCount += 1

        // Update supporter badges
        isSupporter = totalTipsAmount >= 5.0
        isPowerSupporter = totalTipsAmount >= 10.0

        // Save to UserDefaults
        UserDefaults.standard.set(totalTipsAmount, forKey: totalTipsKey)
        UserDefaults.standard.set(tipCount, forKey: tipCountKey)

        print("💰 TippingManager: Tip recorded - $\(doubleAmount) (Total: $\(totalTipsAmount))")
    }

    /// Load supporter status from UserDefaults
    private func loadSupporterStatus() {
        totalTipsAmount = UserDefaults.standard.double(forKey: totalTipsKey)
        tipCount = UserDefaults.standard.integer(forKey: tipCountKey)
        isSupporter = totalTipsAmount >= 5.0
        isPowerSupporter = totalTipsAmount >= 10.0
    }

    /// Reset supporter status (for testing)
    public func resetSupporterStatus() {
        totalTipsAmount = 0
        tipCount = 0
        isSupporter = false
        isPowerSupporter = false
        UserDefaults.standard.removeObject(forKey: totalTipsKey)
        UserDefaults.standard.removeObject(forKey: tipCountKey)
    }

    // MARK: - Tip Prompt Triggers

    /// Record that a speed test was completed
    public func recordSpeedTestCompleted() {
        let count = UserDefaults.standard.integer(forKey: speedTestCountKey)
        let newCount = count + 1
        UserDefaults.standard.set(newCount, forKey: speedTestCountKey)

        // Show tip prompt after first speed test (if not supporter)
        if newCount == 1 && !isSupporter {
            checkAndShowTipPrompt(trigger: .firstSpeedTest)
        }
        // Show tip prompt every 10 speed tests
        else if newCount % 10 == 0 && !isPowerSupporter {
            checkAndShowTipPrompt(trigger: .frequentUser)
        }
    }

    /// Record that history was exported
    public func recordHistoryExported() {
        let count = UserDefaults.standard.integer(forKey: historyExportCountKey)
        UserDefaults.standard.set(count + 1, forKey: historyExportCountKey)

        // Show tip prompt after first export (if not supporter)
        if count == 0 && !isSupporter {
            checkAndShowTipPrompt(trigger: .historyExport)
        }
    }

    /// Check if enough time has passed since last tip prompt
    private func checkAndShowTipPrompt(trigger: TipPromptTrigger) {
        let now = Date()

        // Don't show prompts more than once per day
        if let lastPrompt = UserDefaults.standard.object(forKey: lastTipPromptKey) as? Date {
            let daysSinceLastPrompt =
                Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            if daysSinceLastPrompt < 1 {
                return
            }
        }

        // Show the prompt
        tipPromptTrigger = trigger
        shouldShowTipPrompt = true
        UserDefaults.standard.set(now, forKey: lastTipPromptKey)
    }

    /// Dismiss tip prompt
    public func dismissTipPrompt() {
        shouldShowTipPrompt = false
        tipPromptTrigger = nil
    }

    // MARK: - Helper Methods

    /// Get supporter badge text
    public var supporterBadge: String? {
        if isPowerSupporter {
            return "⭐️ Power Supporter"
        } else if isSupporter {
            return "💙 Supporter"
        }
        return nil
    }

    /// Get impact message based on total tips
    public var impactMessage: String {
        if totalTipsAmount >= 20 {
            return "Your incredible support is helping build the ISP comparison feature!"
        } else if totalTipsAmount >= 10 {
            return "Your generous support is funding new analytics features!"
        } else if totalTipsAmount >= 5 {
            return "Your support is helping improve the app!"
        } else {
            return "Your tip will help fund new features like ISP comparison and WiFi ratings!"
        }
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public enum TipPromptTrigger {
    case firstSpeedTest
    case historyExport
    case frequentUser

    var title: String {
        switch self {
        case .firstSpeedTest:
            return "Enjoying OnlineNow?"
        case .historyExport:
            return "Thanks for using OnlineNow!"
        case .frequentUser:
            return "You're a power user!"
        }
    }

    var message: String {
        switch self {
        case .firstSpeedTest:
            return
                "Your first speed test is complete! If you find this useful, consider buying me a coffee. ☕️"
        case .historyExport:
            return "Glad you're finding the history useful! Support development with a quick tip."
        case .frequentUser:
            return
                "You've been using OnlineNow a lot! Your support helps keep the app free for everyone."
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum TippingError: Error {
    case failedVerification
    case unknownError
}
