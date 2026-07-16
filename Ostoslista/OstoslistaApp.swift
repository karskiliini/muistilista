import SwiftUI
import SwiftData
import WidgetKit

@main
struct OstoslistaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer = {
        do {
            return try SharedStore.container()
        } catch {
            fatalError("Cannot open shared store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
