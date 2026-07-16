import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var name: String
    var isDone: Bool
    var createdAt: Date
    var quantity: Int = 1

    init(name: String, isDone: Bool = false, createdAt: Date = .now, quantity: Int = 1) {
        self.name = name
        self.isDone = isDone
        self.createdAt = createdAt
        self.quantity = quantity
    }
}
