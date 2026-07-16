import CoreData

/// Root of the shared record hierarchy: the CKShare is attached to the
/// list, and every item hangs off it via the `list` relationship.
@objc(CDShoppingList)
final class CDShoppingList: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var items: Set<CDShoppingItem>
    @NSManaged var shelfMemories: Set<CDShelfMemory>

    override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(Date.now, forKey: "createdAt")
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDShoppingList> {
        NSFetchRequest<CDShoppingList>(entityName: "CDShoppingList")
    }
}
