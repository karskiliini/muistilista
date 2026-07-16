import CoreData

/// Core Data stack with a programmatic model (no .xcdatamodeld) and the
/// store in the shared App Group so the app and widget read the same
/// database. All attributes carry defaults and CloudKit-safe types —
/// required when NSPersistentCloudKitContainer arrives in phase 2.
enum CoreDataStack {
    static let appGroupID = "group.fi.maaranen.ostoslista"
    /// Marks this device's own saves in persistent history, so remote-change
    /// banners fire only for transactions authored elsewhere.
    static let transactionAuthor = "ostoslista-app"

    /// One model instance per process; multiple models claiming the same
    /// NSManagedObject subclass corrupt entity lookups.
    static let model: NSManagedObjectModel = {
        let entity = NSEntityDescription()
        entity.name = "CDShoppingItem"
        entity.managedObjectClassName = "CDShoppingItem"

        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.defaultValue = ""

        let isDone = NSAttributeDescription()
        isDone.name = "isDone"
        isDone.attributeType = .booleanAttributeType
        isDone.defaultValue = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.defaultValue = Date(timeIntervalSince1970: 0)

        let quantity = NSAttributeDescription()
        quantity.name = "quantity"
        quantity.attributeType = .integer64AttributeType
        quantity.defaultValue = 1

        // Stable identity for cross-device dedupe (CloudKit has no
        // uniqueness constraints). Optional so old rows migrate cleanly.
        let uuid = NSAttributeDescription()
        uuid.name = "uuid"
        uuid.attributeType = .UUIDAttributeType
        uuid.isOptional = true

        entity.properties = [name, isDone, createdAt, quantity, uuid]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }()

    static let cloudKitContainerID = "iCloud.fi.maaranen.ostoslista"

    /// `cloudKit: true` (the app) syncs through CloudKit; the widget and
    /// tests read the same store without any CloudKit machinery.
    static func container(inMemory: Bool = false, cloudKit: Bool = false) -> NSPersistentContainer {
        let container: NSPersistentContainer = cloudKit
            ? NSPersistentCloudKitContainer(name: "Ostoslista", managedObjectModel: model)
            : NSPersistentContainer(name: "Ostoslista", managedObjectModel: model)
        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            } else if let base = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                description.url = base.appendingPathComponent("OstoslistaCD.sqlite")
                // Both processes must agree on history tracking once the
                // CloudKit-syncing app enables it.
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber,
                                      forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                if cloudKit {
                    description.cloudKitContainerOptions =
                        NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
                }
            }
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("Cannot load store: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.transactionAuthor = transactionAuthor
        if cloudKit {
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        return container
    }
}
