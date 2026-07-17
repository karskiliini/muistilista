import SwiftUI
import WidgetKit

@main
struct OstoslistaApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StoreProvider()

    init() {
        CrashReporter.install()
        // Warm the web engines (K-ruoka, Gigantti) so their first search is
        // fast — both need a WKWebView to pass their bot challenge.
        Task { @MainActor in
            KRuokaWebEngine.shared.warmUp()
            GigantiWebEngine.shared.warmUp()
        }
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
