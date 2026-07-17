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
    @NSManaged var catalogPrice: String?
    @NSManaged var priceValue: Double        // 0 for free-text items
    @NSManaged var productDescription: String?
    @NSManaged var imageURLsString: String?

    /// Line total (unit price × quantity); 0 when the item has no price.
    var lineTotal: Double { priceValue * Double(quantity) }

    /// Catalog image URLs (stored newline-joined); empty for free-text items.
    /// Repairs the earlier broken s-cloud modifier/extension so items added
    /// before the fix still render.
    var imageURLs: [URL] {
        (imageURLsString ?? "")
            .split(separator: "\n")
            .map { $0.replacingOccurrences(of: "w_240,h_240,c_fit", with: "w280h280@_q75") }
            .map { $0.contains("cdn.s-cloud.fi") ? $0.replacingOccurrences(of: ".png", with: ".webp") : $0 }
            .compactMap { URL(string: $0) }
    }

    /// A store-sourced item carries at least a store name.
    var isFromStore: Bool { (storeName ?? "").isEmpty == false }

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
