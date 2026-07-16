import CoreData
import CloudKit
import SwiftUI

/// Owns the CloudKit-backed container. NSPersistentCloudKitContainer has no
/// public "sync now" API, so refreshes reload the persistent store in place,
/// which restarts the mirroring delegate and runs a fresh import. Reloading
/// mid-export once duplicated records, so a refresh now waits for CloudKit
/// quiescence first, and a deterministic dedupe pass cleans up any
/// duplicates that still slip through.
final class StoreProvider: ObservableObject {
    let container: NSPersistentContainer
    private var isRefreshing = false
    private var activeCloudEvents: Set<UUID> = []
    private var dedupeWork: DispatchWorkItem?

    init() {
        container = CoreDataStack.container(cloudKit: true)

        NotificationCenter.default.addObserver(
            forName: PushDelegate.pushReceived, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshFromCloud() }
        }
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            if event.endDate == nil {
                self?.activeCloudEvents.insert(event.identifier)
            } else {
                self?.activeCloudEvents.remove(event.identifier)
            }
        }
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleDedupe()
        }
        #if targetEnvironment(macCatalyst)
        // Catalyst throttles silent pushes hard; poll as a fallback.
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshFromCloud() }
        }
        #endif
    }

    /// Pull-to-refresh: refresh + hold the spinner briefly while the import lands.
    @MainActor
    func forceRefresh() async {
        await refreshFromCloud()
        try? await Task.sleep(for: .seconds(1.5))
    }

    @MainActor
    private func refreshFromCloud() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Reach quiescence before touching the store: flush local edits and
        // wait (max 5 s) for in-flight CloudKit events, so an interrupted
        // export can't re-create records on the next cycle.
        let context = container.viewContext
        if context.hasChanges { try? context.save() }
        for _ in 0..<25 where !activeCloudEvents.isEmpty {
            try? await Task.sleep(for: .milliseconds(200))
        }

        // Remove + reload synchronously on the main actor so no view update
        // can observe the store-less window in between.
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
        activeCloudEvents.removeAll()
        container.loadPersistentStores { _, error in
            if let error { assertionFailure("Store reload failed: \(error)") }
        }
    }

    private func scheduleDedupe() {
        dedupeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.dedupe() }
        }
        dedupeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    /// CloudKit has no uniqueness constraints, so sync hiccups can duplicate
    /// records. Every device deletes the same deterministically chosen
    /// victims (per group, the smallest CKRecord name survives), so
    /// concurrent passes on different devices converge on one copy.
    @MainActor
    private func dedupe() {
        guard let ckContainer = container as? NSPersistentCloudKitContainer,
              let items = try? container.viewContext.fetch(CDShoppingItem.fetchRequest()),
              items.count > 1 else { return }

        let rows = items.map { item in
            (id: item.objectID,
             // Old rows have no uuid; fall back to full-content identity.
             key: item.uuid?.uuidString
                ?? "\(item.name)|\(item.createdAt.timeIntervalSince1970)|\(item.isDone)|\(item.quantity)",
             tiebreak: ckContainer.recordID(for: item.objectID)?.recordName
                ?? item.objectID.uriRepresentation().absoluteString)
        }
        let victims = ShoppingListLogic.duplicatesToDelete(rows)
        guard !victims.isEmpty else { return }

        for id in victims {
            if let object = try? container.viewContext.existingObject(with: id) {
                container.viewContext.delete(object)
            }
        }
        try? container.viewContext.save()
    }
}
