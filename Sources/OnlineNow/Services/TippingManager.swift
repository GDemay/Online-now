import Combine
import Foundation
import StoreKit

/// Handles the optional, repeatable tip using verified StoreKit 2 transactions.
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public final class TippingManager: ObservableObject {
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?
    #if DEBUG
    @Published private(set) var visualReviewErrorDiagnostics: String?
    #endif
    @Published public private(set) var isPurchasing = false
    @Published public private(set) var isPending = false
    @Published public private(set) var tipCount = 0
    @Published public private(set) var isSupporter = false
    @Published public private(set) var isPowerSupporter = false

    /// Kept for source compatibility. Historic totals were not currency-aware;
    /// new tips are counted rather than adding incompatible local currencies.
    @available(*, deprecated, message: "Use tipCount; tips may use different currencies.")
    public var totalTipsAmount: Double { defaults.double(forKey: "onlinenow.totalTips") }

    @Published public var shouldShowTipPrompt = false
    @Published public var tipPromptTrigger: TipPromptTrigger?

    // Must exactly match the consumable configured in App Store Connect.
    static let productIDs: Set<String> = ["onlinenow.gdemay"]
    private static let ledgerKey = "onlinenow.tipLedger.v1"
    private let defaults: UserDefaults
    private var ledger: TipLedger
    private var ledgerIsReadable = true
    private var transactionListener: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private let speedTestCountKey = "onlinenow.speedTestCount"
    private let historyExportCountKey = "onlinenow.historyExportCount"
    private let lastTipPromptKey = "onlinenow.lastTipPrompt"

    public convenience init() {
        self.init(defaults: .standard, startsStoreKit: true)
    }

    /// Separate persistence and StoreKit startup so accounting can be tested
    /// without contacting the App Store or modifying a user's defaults.
    init(defaults: UserDefaults, startsStoreKit: Bool) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.ledgerKey) {
            do {
                ledger = try JSONDecoder().decode(TipLedger.self, from: data)
            } catch {
                ledger = TipLedger()
                ledgerIsReadable = false
                errorMessage = "Your local tip history could not be read. Please contact support before sending another tip."
            }
        } else {
            ledger = TipLedger(legacyTipCount: max(0, defaults.integer(forKey: "onlinenow.tipCount")))
        }
        refreshSupporterStatus()

        guard startsStoreKit else { return }
        // Listen before querying unfinished purchases so no delivery is missed.
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.process(result)
            }
        }
        startupTask = Task { [weak self] in
            for await result in Transaction.unfinished {
                guard !Task.isCancelled else { return }
                await self?.process(result)
            }
            await self?.loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
        startupTask?.cancel()
    }

    public func loadProducts() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing"), args.contains("--visual-review") {
            // Rendering fixtures only; purchase workflow tests use a real SKTestSession.
            if args.contains("--tip-loading") {
                isLoading = true
                return
            }
            if args.contains("--tip-unavailable") {
                products = []
                isLoading = false
                errorMessage = "We couldn’t connect to the App Store. Check your connection and try again."
                return
            }
        }
        #endif
        guard !isLoading, !isPurchasing else { return }
        guard ledgerIsReadable else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Array(Self.productIDs))
            products = loaded.filter {
                Self.productIDs.contains($0.id) && $0.type == .consumable
            }.sorted { $0.price < $1.price }
            if products.isEmpty {
                errorMessage = "Tipping is currently unavailable. Please try again later. All app features remain free."
            }
        } catch {
            products = []
            errorMessage = "We couldn’t connect to the App Store. Check your connection and try again."
        }
    }

    /// Returns true only after a verified tip has been saved locally and finished.
    public func purchase(_ product: Product) async -> Bool {
        await purchase(product, performPurchase: { try await $0.purchase() })
    }

    /// The view supplies its scene-aware StoreKit action. Accounting, verified
    /// delivery, pending state, and error handling stay in this manager.
    func purchase(
        _ product: Product,
        performPurchase: @MainActor (Product) async throws -> Product.PurchaseResult
    ) async -> Bool {
        guard !isPurchasing, !isPending, ledgerIsReadable else { return false }
        guard Self.productIDs.contains(product.id), product.type == .consumable else {
            errorMessage = "This tip option is unavailable. Please reload the tip jar."
            return false
        }
        isPurchasing = true
        errorMessage = nil
        #if DEBUG
        if visualReviewDiagnosticsEnabled { visualReviewErrorDiagnostics = nil }
        #endif
        defer { isPurchasing = false }
        do {
            switch try await performPurchase(product) {
            case .success(let result):
                return await process(result)
            case .userCancelled:
                return false
            case .pending:
                isPending = true
                return false
            @unknown default:
                errorMessage = "The App Store hasn’t confirmed this tip. Please try again later."
                return false
            }
        } catch StoreKitError.userCancelled {
            // StoreKit may deliver cancellation as either a result or an error.
            // Neither is a failed payment or a reason to show an error message.
            return false
        } catch let error as SKError where error.code == .paymentCancelled {
            return false
        } catch is CancellationError {
            return false
        } catch {
            #if DEBUG
            recordVisualReviewError(error)
            #endif
            errorMessage = "Your tip couldn’t be completed. Please try again."
            return false
        }
    }

    #if DEBUG
    private var visualReviewDiagnosticsEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--ui-testing") && args.contains("--visual-review")
    }

    /// Deliberately excludes descriptions, userInfo values, accounts, URLs, and payloads.
    private func recordVisualReviewError(_ error: Error) {
        guard visualReviewDiagnosticsEnabled else { return }
        func node(_ current: Error, depth: Int) -> [String: Any] {
            let bridged = current as NSError
            var result: [String: Any] = [
                "type": String(reflecting: type(of: current)),
                "domain": bridged.domain,
                "code": bridged.code
            ]
            guard depth < 5 else { return result } // At most six nested levels.
            var underlying: [[String: Any]] = []
            if let storeKit = current as? StoreKitError {
                if #available(iOS 27.0, macOS 27.0, *) , case .invalidPresentationContext = storeKit {
                    result["storeKitCase"] = "invalidPresentationContext"
                } else if #available(iOS 18.4, macOS 15.4, *), case .unsupported = storeKit {
                    result["storeKitCase"] = "unsupported"
                } else if #available(iOS 15.4, macOS 12.3, *), case .notEntitled = storeKit {
                    result["storeKitCase"] = "notEntitled"
                } else {
                    switch storeKit {
                    case .unknown: result["storeKitCase"] = "unknown"
                    case .userCancelled: result["storeKitCase"] = "userCancelled"
                    case .networkError: result["storeKitCase"] = "networkError"
                    case .systemError: result["storeKitCase"] = "systemError"
                    case .notAvailableInStorefront: result["storeKitCase"] = "notAvailableInStorefront"
                    default: result["storeKitCase"] = "other"
                    }
                }
                switch storeKit {
                case let .systemError(systemError): underlying.append(node(systemError, depth: depth + 1))
                case let .networkError(networkError): underlying.append(node(networkError, depth: depth + 1))
                default: break
                }
            }
            if let nested = bridged.userInfo[NSUnderlyingErrorKey] as? Error {
                underlying.append(node(nested, depth: depth + 1))
            }
            if !underlying.isEmpty { result["underlying"] = underlying }
            return result
        }
        if let data = try? JSONSerialization.data(withJSONObject: node(error, depth: 0), options: [.sortedKeys]) {
            visualReviewErrorDiagnostics = String(data: data, encoding: .utf8)
        }
    }
    #endif

    @discardableResult
    private func process(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else {
            errorMessage = "The App Store couldn’t verify this tip. Please try again later."
            return false
        }
        guard Self.productIDs.contains(transaction.productID), transaction.productType == .consumable else {
            // Other StoreKit consumers must finish their own transactions.
            return false
        }
        guard ledgerIsReadable else { return false }
        let isRevoked = transaction.revocationDate != nil
        do {
            try recordVerifiedTip(id: transaction.id, productID: transaction.productID, isRevoked: isRevoked)
            // Persist before finishing, so interruption causes safe redelivery.
            await transaction.finish()
            isPending = false
            return !isRevoked
        } catch {
            errorMessage = "Your purchase is safe with the App Store, but we couldn’t save its confirmation. Reopen the app to try again."
            return false
        }
    }

    /// Shared by purchase results, delayed approvals, and unfinished redelivery.
    @discardableResult
    func recordVerifiedTip(id: UInt64, productID: String, isRevoked: Bool) throws -> Bool {
        guard Self.productIDs.contains(productID), ledgerIsReadable else { return false }
        var nextLedger = ledger
        let changed = nextLedger.record(id: id, productID: productID, isRevoked: isRevoked)
        guard changed else { return false }
        let data = try JSONEncoder().encode(nextLedger)
        defaults.set(data, forKey: Self.ledgerKey)
        ledger = nextLedger
        refreshSupporterStatus()
        return true
    }

    private func refreshSupporterStatus() {
        tipCount = ledger.tipCount
        isSupporter = tipCount > 0
        isPowerSupporter = tipCount >= 10
    }

    /// Reset local status for test tooling. Never called from the purchase UI.
    public func resetSupporterStatus() {
        ledger = TipLedger()
        ledgerIsReadable = true
        defaults.removeObject(forKey: Self.ledgerKey)
        defaults.removeObject(forKey: "onlinenow.totalTips")
        defaults.removeObject(forKey: "onlinenow.tipCount")
        refreshSupporterStatus()
    }

    public func recordSpeedTestCompleted() {
        let count = defaults.integer(forKey: speedTestCountKey) + 1
        defaults.set(count, forKey: speedTestCountKey)
        // Let people finish their first test without immediately asking for money.
        if count >= 10, count % 10 == 0, !isSupporter {
            checkAndShowTipPrompt(trigger: .frequentUser)
        }
    }

    public func recordHistoryExported() {
        let count = defaults.integer(forKey: historyExportCountKey) + 1
        defaults.set(count, forKey: historyExportCountKey)
    }

    private func checkAndShowTipPrompt(trigger: TipPromptTrigger) {
        guard !shouldShowTipPrompt, !isSupporter else { return }
        let now = Date()
        if let lastPrompt = defaults.object(forKey: lastTipPromptKey) as? Date,
           now.timeIntervalSince(lastPrompt) < 7 * 24 * 60 * 60 {
            return
        }
        tipPromptTrigger = trigger
        shouldShowTipPrompt = true
        defaults.set(now, forKey: lastTipPromptKey)
    }

    public func dismissTipPrompt() {
        shouldShowTipPrompt = false
        tipPromptTrigger = nil
    }

    public var supporterBadge: String? {
        isPowerSupporter ? "⭐️ Power Supporter" : (isSupporter ? "💙 Supporter" : nil)
    }

    public var impactMessage: String {
        "Thank you for helping maintain Online Now. Every feature remains free for everyone."
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum TipPromptTrigger {
    case firstSpeedTest
    case historyExport
    case frequentUser

    var title: String { "Support Online Now" }
    var message: String {
        "Finding Online Now useful? An optional tip helps keep the app maintained. Every feature remains free."
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum TippingError: Error {
    case failedVerification
    case unknownError
}
