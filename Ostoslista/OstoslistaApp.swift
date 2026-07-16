import SwiftUI
import WidgetKit

@main
struct OstoslistaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let container = CoreDataStack.container(cloudKit: true)

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environment(\.managedObjectContext, container.viewContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
