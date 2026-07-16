import Foundation

/// The minimum surface the list logic needs — keeps the logic and its
/// tests independent of the persistence framework.
protocol ShoppingItemLike {
    var isDone: Bool { get }
    var createdAt: Date { get }
}

enum ShoppingListLogic {
    /// Trimmed input, or nil when nothing remains.
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Unchecked first; within each group oldest first.
    static func sorted<Item: ShoppingItemLike>(_ items: [Item]) -> [Item] {
        items.sorted {
            if $0.isDone != $1.isDone { return !$0.isDone }
            return $0.createdAt < $1.createdAt
        }
    }

    static func checked<Item: ShoppingItemLike>(_ items: [Item]) -> [Item] {
        items.filter(\.isDone)
    }

    /// Maps a horizontal drag to a quantity: one step per 36 pt from
    /// `start`, clamped to a minimum of 1.
    static func quantity(start: Int, dragWidth: CGFloat) -> Int {
        max(1, start + Int(dragWidth / 36))
    }

    /// Normalized key for shelf-memory lookups: the same product matches
    /// regardless of letter case and surrounding whitespace.
    static func shelfKey(_ product: String) -> String {
        product.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// One-line summary of a remote change batch for the notification
    /// banner, or nil when there is nothing worth announcing.
    static func changeSummary(added: [String], updated: [String], deletedCount: Int) -> String? {
        var parts: [String] = []
        parts += added.map { "+ \($0)" }
        parts += updated.map { "~ \($0)" }
        if deletedCount > 0 {
            parts.append(deletedCount == 1 ? "– 1 rivi" : "– \(deletedCount) riviä")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Groups rows by `key`; in each group the row with the smallest
    /// `tiebreak` survives and the rest are returned for deletion. Every
    /// device computes the same survivors, so concurrent dedupe passes on
    /// different devices cannot wipe out both copies.
    static func duplicatesToDelete<ID>(_ rows: [(id: ID, key: String, tiebreak: String)]) -> [ID] {
        var winners: [String: (id: ID, tiebreak: String)] = [:]
        var victims: [ID] = []
        for row in rows {
            if let current = winners[row.key] {
                if row.tiebreak < current.tiebreak {
                    victims.append(current.id)
                    winners[row.key] = (row.id, row.tiebreak)
                } else {
                    victims.append(row.id)
                }
            } else {
                winners[row.key] = (row.id, row.tiebreak)
            }
        }
        return victims
    }
}
