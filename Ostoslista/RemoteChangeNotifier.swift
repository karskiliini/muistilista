import CoreData
import UserNotifications

/// Watches persistent history for transactions authored somewhere else
/// (CloudKit imports from other devices) and raises a local banner
/// describing what changed. Tapping the banner opens the app.
final class RemoteChangeNotifier {
    private static let tokenKey = "lastSeenHistoryToken"

    private let container: NSPersistentContainer
    private var work: DispatchWorkItem?

    init(container: NSPersistentContainer) {
        self.container = container
        // First run: record a baseline so old history isn't announced.
        if savedToken == nil { saveCurrentTokenAsBaseline() }
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.schedule()
        }
    }

    /// Debounce: one banner per import batch, not one per row.
    private func schedule() {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.process() }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private var savedToken: NSPersistentHistoryToken? {
        guard let data = UserDefaults.standard.data(forKey: Self.tokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
    }

    private func save(token: NSPersistentHistoryToken) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: Self.tokenKey)
        }
    }

    private func saveCurrentTokenAsBaseline() {
        let coordinator = container.persistentStoreCoordinator
        if let token = coordinator.currentPersistentHistoryToken(fromStores: coordinator.persistentStores) {
            save(token: token)
        }
    }

    private func process() {
        let context = container.newBackgroundContext()
        context.perform { [weak self] in
            guard let self else { return }
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: self.savedToken)
            guard let result = try? context.execute(request) as? NSPersistentHistoryResult,
                  let transactions = result.result as? [NSPersistentHistoryTransaction],
                  let last = transactions.last else { return }

            var added: [String] = []
            var updated: [String] = []
            var deleted = 0
            for tx in transactions where tx.author != CoreDataStack.transactionAuthor {
                for change in tx.changes ?? [] {
                    switch change.changeType {
                    case .insert:
                        if let item = try? context.existingObject(with: change.changedObjectID) as? CDShoppingItem {
                            added.append(item.name)
                        }
                    case .update:
                        if let item = try? context.existingObject(with: change.changedObjectID) as? CDShoppingItem {
                            updated.append(item.name)
                        }
                    case .delete:
                        deleted += 1
                    @unknown default:
                        break
                    }
                }
            }
            self.save(token: last.token)

            guard let body = ShoppingListLogic.changeSummary(
                added: added, updated: updated, deletedCount: deleted
            ) else { return }
            let content = UNMutableNotificationContent()
            content.title = "Ostoslista päivittyi"
            content.body = body
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }
}
