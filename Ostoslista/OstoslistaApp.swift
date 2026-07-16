import SwiftUI
import SwiftData

@main
struct OstoslistaApp: App {
    var body: some Scene {
        WindowGroup {
            ShoppingListView()
        }
        .modelContainer(for: ShoppingItem.self)
    }
}
