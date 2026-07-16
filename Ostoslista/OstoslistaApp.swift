import SwiftUI
import WidgetKit

@main
struct OstoslistaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StoreProvider()

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environment(\.managedObjectContext, store.container.viewContext)
                .environmentObject(store)
                .id(store.generation)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
