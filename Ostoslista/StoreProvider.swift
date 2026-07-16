import CoreData
import SwiftUI

/// Owns the CloudKit-backed container. NSPersistentCloudKitContainer has no
/// public "sync now" API, so refreshes reload the persistent store in
/// place — that restarts the mirroring delegate, which runs a fresh import.
/// The container and viewContext instances never change, so SwiftUI keeps
/// its view identity and the refresh control retracts with its native
/// animation instead of the list jumping.
final class StoreProvider: ObservableObject {
    let container: NSPersistentContainer
    private var isRefreshing = false

    init() {
        container = CoreDataStack.container(cloudKit: true)
        NotificationCenter.default.addObserver(
            forName: PushDelegate.pushReceived, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reloadStores() }
        }
    }

    /// Pull-to-refresh: reload + hold the spinner briefly while the import lands.
    @MainActor
    func forceRefresh() async {
        reloadStores()
        try? await Task.sleep(for: .seconds(2))
    }

    /// Remove + reload synchronously on the main actor so no view update can
    /// observe the store-less window in between.
    @MainActor
    private func reloadStores() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
        container.loadPersistentStores { _, error in
            if let error { assertionFailure("Store reload failed: \(error)") }
        }
    }
}
