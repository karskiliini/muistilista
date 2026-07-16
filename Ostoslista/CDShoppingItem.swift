import CoreData

@objc(CDShoppingItem)
final class CDShoppingItem: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var isDone: Bool
    @NSManaged var createdAt: Date
    @NSManaged var quantity: Int64
    @NSManaged var uuid: UUID?
    @NSManaged var list: CDShoppingList?
    @NSManaged var storeName: String?
    @NSManaged var shelfLocation: String?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(Date.now, forKey: "createdAt")
        setPrimitiveValue(UUID(), forKey: "uuid")
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDShoppingItem> {
        NSFetchRequest<CDShoppingItem>(entityName: "CDShoppingItem")
    }
}

extension CDShoppingItem: ShoppingItemLike {}
extension CDShoppingItem: Identifiable {}
