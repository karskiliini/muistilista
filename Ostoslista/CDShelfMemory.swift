import CoreData

/// Family shelf memory: (product, store) → shelf location. Rides the same
/// shared hierarchy as the list, so the whole family benefits from one
/// member noting where something lives in a store.
@objc(CDShelfMemory)
final class CDShelfMemory: NSManagedObject {
    @NSManaged var productKey: String
    @NSManaged var storeName: String
    @NSManaged var shelfLocation: String
    @NSManaged var updatedAt: Date
    @NSManaged var list: CDShoppingList?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(Date.now, forKey: "updatedAt")
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDShelfMemory> {
        NSFetchRequest<CDShelfMemory>(entityName: "CDShelfMemory")
    }
}
