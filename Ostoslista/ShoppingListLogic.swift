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
}
