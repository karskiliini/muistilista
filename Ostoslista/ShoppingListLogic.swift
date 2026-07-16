import Foundation

enum ShoppingListLogic {
    /// Trimmed input, or nil when nothing remains.
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Unchecked first; within each group oldest first.
    static func sorted(_ items: [ShoppingItem]) -> [ShoppingItem] {
        items.sorted {
            if $0.isDone != $1.isDone { return !$0.isDone }
            return $0.createdAt < $1.createdAt
        }
    }

    static func checked(_ items: [ShoppingItem]) -> [ShoppingItem] {
        items.filter(\.isDone)
    }
}
