import SwiftUI
import WidgetKit

@main
struct OstoslistaApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StoreProvider()

    init() {
        CrashReporter.install()
    }

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environment(\.managedObjectContext, store.container.viewContext)
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
