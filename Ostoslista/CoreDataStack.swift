import CoreData
import CloudKit

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

        let listEntity = NSEntityDescription()
        listEntity.name = "CDShoppingList"
        listEntity.managedObjectClassName = "CDShoppingList"

        let listName = NSAttributeDescription()
        listName.name = "name"
        listName.attributeType = .stringAttributeType
        listName.defaultValue = "Ostoslista"

        let listCreatedAt = NSAttributeDescription()
        listCreatedAt.name = "createdAt"
        listCreatedAt.attributeType = .dateAttributeType
        listCreatedAt.defaultValue = Date(timeIntervalSince1970: 0)

        // CloudKit requires optional, unordered relationships.
        let itemsRel = NSRelationshipDescription()
        itemsRel.name = "items"
        itemsRel.destinationEntity = entity
        itemsRel.minCount = 0
        itemsRel.maxCount = 0
        itemsRel.isOptional = true
        itemsRel.deleteRule = .cascadeDeleteRule

        let listRel = NSRelationshipDescription()
        listRel.name = "list"
        listRel.destinationEntity = listEntity
        listRel.minCount = 0
        listRel.maxCount = 1
        listRel.isOptional = true
        listRel.deleteRule = .nullifyDeleteRule

        itemsRel.inverseRelationship = listRel
        listRel.inverseRelationship = itemsRel

        entity.properties = [name, isDone, createdAt, quantity, uuid, listRel]
        listEntity.properties = [listName, listCreatedAt, itemsRel]

        let model = NSManagedObjectModel()
        model.entities = [entity, listEntity]
        return model
    }()

    static let cloudKitContainerID = "iCloud.fi.maaranen.ostoslista"

    /// `cloudKit: true` (the app) syncs through CloudKit; the widget and
    /// tests read the same store without any CloudKit machinery.
    static func container(inMemory: Bool = false, cloudKit: Bool = false) -> NSPersistentContainer {
        let container: NSPersistentContainer = cloudKit
            ? NSPersistentCloudKitContainer(name: "Ostoslista", managedObjectModel: model)
            : NSPersistentContainer(name: "Ostoslista", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            // Two stores: the user's own data (private database) and lists
            // shared TO the user by others (shared database). Order matters:
            // new objects land in the first store unless assigned explicitly.
            let privateDesc = NSPersistentStoreDescription(
                url: base.appendingPathComponent("OstoslistaCD.sqlite"))
            let sharedDesc = NSPersistentStoreDescription(
                url: base.appendingPathComponent("OstoslistaCD-shared.sqlite"))
            for description in [privateDesc, sharedDesc] {
                // Both processes must agree on history tracking once the
                // CloudKit-syncing app enables it.
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber,
                                      forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }
            if cloudKit {
                privateDesc.cloudKitContainerOptions =
                    NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
                let sharedOptions =
                    NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
                sharedOptions.databaseScope = .shared
                sharedDesc.cloudKitContainerOptions = sharedOptions
            }
            container.persistentStoreDescriptions = [privateDesc, sharedDesc]
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
