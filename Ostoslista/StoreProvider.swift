import CoreData
import SwiftUI

/// Owns the CloudKit-backed container. NSPersistentCloudKitContainer has no
/// public "sync now" API, so force-refresh rebuilds the container — loading
/// the store starts a fresh import cycle against CloudKit.
final class StoreProvider: ObservableObject {
    @Published private(set) var container: NSPersistentContainer
    private(set) var generation = 0

    init() {
        container = CoreDataStack.container(cloudKit: true)
    }

    @MainActor
    func forceRefresh() async {
        generation += 1
        container = CoreDataStack.container(cloudKit: true)
        // Give the fresh mirroring delegate a moment to pull changes; the
        // sleep may be cancelled when the view hierarchy rebuilds — fine,
        // the import continues in the background either way.
        try? await Task.sleep(for: .seconds(2.5))
    }
}
