import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var name: String
    var isDone: Bool
    var createdAt: Date

    init(name: String, isDone: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.isDone = isDone
        self.createdAt = createdAt
    }
}
