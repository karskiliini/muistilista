import CoreData
import CloudKit
import SwiftUI

/// Owns the CloudKit-backed container. NSPersistentCloudKitContainer has no
/// public "sync now" API, so refreshes reload the persistent store in place,
/// which restarts the mirroring delegate and runs a fresh import. Reloading
/// mid-export once duplicated records, so a refresh now waits for CloudKit
/// quiescence first, and a deterministic dedupe pass cleans up any
/// duplicates that still slip through.
/// Global access point for delegate callbacks (share acceptance) that have
/// no path to the SwiftUI environment.
enum AppStores {
    static weak var provider: StoreProvider?
}

final class StoreProvider: ObservableObject {
    let container: NSPersistentContainer
    @Published private(set) var currentList: CDShoppingList?
    private var isRefreshing = false
    private var activeCloudEvents: Set<UUID> = []
    private var dedupeWork: DispatchWorkItem?
    private var remoteChangeNotifier: RemoteChangeNotifier?

    init() {
        container = CoreDataStack.container(cloudKit: true)
        remoteChangeNotifier = RemoteChangeNotifier(container: container)
        AppStores.provider = self
        Task { @MainActor in self.ensureList() }

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
        ensureList()
    }

    // MARK: - List resolution and sharing

    private var sharedStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores
            .first { $0.url?.lastPathComponent.contains("shared") == true }
    }

    /// The single list this device works on. A list living in the shared
    /// store wins (family member case); otherwise the own private list is
    /// used or created. Orphan items from older versions are adopted.
    @MainActor
    func ensureList() {
        let context = container.viewContext
        let lists = (try? context.fetch(CDShoppingList.fetchRequest())) ?? []
        let resolved = lists.first { $0.objectID.persistentStore == sharedStore }
            ?? lists.sorted { $0.createdAt < $1.createdAt }.first
        let list: CDShoppingList
        if let resolved {
            list = resolved
        } else {
            list = CDShoppingList(context: context)
            list.name = "Ostoslista"
        }
        let items = (try? context.fetch(CDShoppingItem.fetchRequest())) ?? []
        for item in items
        where item.list == nil && item.objectID.persistentStore == list.objectID.persistentStore {
            item.list = list
        }
        if context.hasChanges { try? context.save() }
        currentList = list
    }

    /// Existing CKShare for the list, or a new one (moves the hierarchy
    /// into a shared CloudKit zone).
    @MainActor
    func fetchOrCreateShare() async throws -> (CKShare, CKContainer) {
        guard let ck = container as? NSPersistentCloudKitContainer,
              let list = currentList else {
            throw CocoaError(.persistentStoreOperation)
        }
        let ckContainer = CKContainer(identifier: CoreDataStack.cloudKitContainerID)
        if let share = try? ck.fetchShares(matching: [list.objectID])[list.objectID] {
            return (share, ckContainer)
        }
        let (_, share, shareContainer) = try await ck.share([list], to: nil)
        share[CKShare.SystemFieldKey.title] = "Ostoslista" as CKRecordValue
        return (share, shareContainer)
    }

    /// Called when the user accepts a share invitation (family member side).
    func acceptShare(metadata: CKShare.Metadata) {
        guard let ck = container as? NSPersistentCloudKitContainer,
              let sharedStore else { return }
        ck.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error { print("Share accept failed: \(error)") }
            Task { @MainActor in
                await self.forceRefresh()
            }
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
