import Foundation

/// A durable record of verified consumable transactions. Keep revoked IDs too so a
/// replayed transaction can never grant support twice.
struct TipLedger: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let productID: String
        var isRevoked: Bool
    }

    var entries: [String: Entry] = [:]
    var legacyTipCount = 0

    var tipCount: Int {
        legacyTipCount + entries.values.filter { !$0.isRevoked }.count
    }

    @discardableResult
    mutating func record(id: UInt64, productID: String, isRevoked: Bool) -> Bool {
        let key = String(id)
        // Once refunded, an older delivery must not restore the transaction.
        if let previous = entries[key] {
            guard !previous.isRevoked, isRevoked else { return false }
            entries[key]?.isRevoked = true
            return true
        }
        entries[key] = Entry(productID: productID, isRevoked: isRevoked)
        return true
    }
}
