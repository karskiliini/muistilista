import XCTest
import CoreData
@testable import Ostoslista

/// Plain fixture — logic must not depend on any persistence framework.
private struct FixtureItem: ShoppingItemLike {
    let isDone: Bool
    let createdAt: Date
    var name: String
}

final class ShoppingListLogicTests: XCTestCase {
    private func item(_ name: String, done: Bool, at seconds: TimeInterval = 0) -> FixtureItem {
        FixtureItem(isDone: done, createdAt: Date(timeIntervalSince1970: seconds), name: name)
    }

    func testNormalizedTrimsWhitespace() {
        XCTAssertEqual(ShoppingListLogic.normalized("  maito \n"), "maito")
    }

    func testNormalizedRejectsEmptyInput() {
        XCTAssertNil(ShoppingListLogic.normalized(""))
        XCTAssertNil(ShoppingListLogic.normalized("   \n\t"))
    }

    func testSortedPutsUncheckedFirstThenOldestFirst() {
        let result = ShoppingListLogic.sorted([
            item("leipä", done: true, at: 1),
            item("maito", done: false, at: 3),
            item("kahvi", done: false, at: 2),
        ])
        XCTAssertEqual(result.map(\.name), ["kahvi", "maito", "leipä"])
    }

    func testCheckedReturnsOnlyCheckedItems() {
        let result = ShoppingListLogic.checked([
            item("leipä", done: true),
            item("maito", done: false),
        ])
        XCTAssertEqual(result.map(\.name), ["leipä"])
    }

    func testQuantityStaysAtStartForShortDrag() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 0), 1)
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 35), 1)
    }

    func testQuantityGrowsOneStepPer36Points() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 36), 2)
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: 200), 6)
    }

    func testQuantityScrubsDownWhenDraggingLeft() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 4, dragWidth: -72), 2)
    }

    func testQuantityNeverGoesBelowOne() {
        XCTAssertEqual(ShoppingListLogic.quantity(start: 2, dragWidth: -500), 1)
        XCTAssertEqual(ShoppingListLogic.quantity(start: 1, dragWidth: -36), 1)
    }

    func testDuplicatesToDeleteKeepsSmallestTiebreakPerGroup() {
        let victims = ShoppingListLogic.duplicatesToDelete([
            (id: "a", key: "k1", tiebreak: "B"),
            (id: "b", key: "k1", tiebreak: "A"),
            (id: "c", key: "k2", tiebreak: "Z"),
        ])
        XCTAssertEqual(victims, ["a"])
    }

    func testSKaupatParseExtractsProductFieldsFromRealShape() {
        let json = """
        {"data":{"store":{"products":{"productListItems":[
          {"product":{
            "id":"6414893386488","name":"Kotimaista kevytmaito 1 L",
            "price":0.95,"priceUnit":"KPL","comparisonPrice":0.95,"comparisonUnit":"LTR",
            "brandName":"Kotimaista",
            "hierarchyPath":[{"name":"Maidot"},{"name":"Maidot ja piimät"},{"name":"Maito, munat ja rasvat"}],
            "productDetails":{"productImages":{"mainImage":{"urlTemplate":"https://cdn.s-cloud.fi/v1/{MODIFIERS}/x.{EXTENSION}"}}}
          }}
        ]}}}}
        """.data(using: .utf8)!
        let products = SKaupatCatalog.parse(json)
        XCTAssertEqual(products.count, 1)
        let p = products[0]
        XCTAssertEqual(p.name, "Kotimaista kevytmaito 1 L")
        XCTAssertEqual(p.price, 0.95)
        XCTAssertEqual(p.priceText, "0,95 €")
        XCTAssertEqual(p.categoryPath.first, "Maidot")
        XCTAssertEqual(p.brand, "Kotimaista")
        XCTAssertNotNil(p.imageURL)
        XCTAssertFalse(p.imageURL!.absoluteString.contains("{MODIFIERS}"))
    }

    func testSKaupatParseReturnsEmptyOnGarbage() {
        XCTAssertEqual(SKaupatCatalog.parse(Data("nonsense".utf8)).count, 0)
    }

    func testSKaupatCatalogHandlesSGroupStoreNames() {
        XCTAssertTrue(SKaupatCatalog.handles(storeName: "Prisma Kuopio"))
        XCTAssertTrue(SKaupatCatalog.handles(storeName: "S-market Saarijärvi"))
        XCTAssertTrue(SKaupatCatalog.handles(storeName: "ALEPA Kallio"))
        XCTAssertFalse(SKaupatCatalog.handles(storeName: "K-Citymarket"))
        XCTAssertFalse(SKaupatCatalog.handles(storeName: "Motonet"))
    }

    func testSKaupatSearchURLEncodesQueryAndStore() {
        let url = SKaupatCatalog.searchURL(query: "ruis leipä", storeId: "42")
        let s = url!.absoluteString
        XCTAssertTrue(s.hasPrefix("https://api.s-kaupat.fi/?operationName=RemoteFilteredProducts"))
        XCTAssertTrue(s.contains("ruis%20leip%C3%A4") || s.contains("ruis+leip%C3%A4"))
        XCTAssertTrue(s.contains("%22storeId%22%3A%2242%22"))
    }

    func testCatalogCategoryHintJoinsBreadcrumbTopDown() {
        XCTAssertEqual(
            ShoppingListLogic.categoryHint(["Maidot", "Maidot ja piimät", "Maito, munat ja rasvat"]),
            "Maito, munat ja rasvat › Maidot ja piimät › Maidot"
        )
        XCTAssertNil(ShoppingListLogic.categoryHint([]))
    }

    func testShelfKeyNormalizesCaseAndWhitespace() {
        XCTAssertEqual(ShoppingListLogic.shelfKey("  Maito "), "maito")
        XCTAssertEqual(ShoppingListLogic.shelfKey("RUISLEIPÄ"), "ruisleipä")
    }

    func testChangeSummaryFormatsAllChangeKinds() {
        XCTAssertEqual(
            ShoppingListLogic.changeSummary(added: ["maito"], updated: ["leipä"], deletedCount: 2),
            "+ maito · ~ leipä · – 2 riviä"
        )
        XCTAssertEqual(
            ShoppingListLogic.changeSummary(added: [], updated: [], deletedCount: 1),
            "– 1 rivi"
        )
    }

    func testChangeSummaryReturnsNilWhenNothingChanged() {
        XCTAssertNil(ShoppingListLogic.changeSummary(added: [], updated: [], deletedCount: 0))
    }

    func testCoreDataRoundTrip() throws {
        let container = CoreDataStack.container(inMemory: true)
        let context = container.viewContext

        let milk = CDShoppingItem(context: context)
        milk.name = "maito"
        milk.quantity = 3
        try context.save()

        let fetched = try context.fetch(CDShoppingItem.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "maito")
        XCTAssertEqual(fetched.first?.quantity, 3)
        XCTAssertEqual(fetched.first?.isDone, false)
    }
}
