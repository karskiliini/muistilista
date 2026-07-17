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
        let url = p.imageURL!.absoluteString
        XCTAssertFalse(url.contains("{MODIFIERS}"))
        // Must use the s-cloud modifier/extension the CDN actually accepts.
        XCTAssertTrue(url.contains("w280h280@_q75"), url)
        XCTAssertTrue(url.hasSuffix(".webp"), url)
    }

    func testStoredSCloudImageURLGetsRepaired() throws {
        let container = CoreDataStack.container(inMemory: true)
        let item = CDShoppingItem(context: container.viewContext)
        item.name = "suola"
        item.imageURLsString = "https://cdn.s-cloud.fi/v1/w_240,h_240,c_fit/assets/dam-id/ABC.png"
        let urls = item.imageURLs
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].absoluteString,
                       "https://cdn.s-cloud.fi/v1/w280h280@_q75/assets/dam-id/ABC.webp")
    }

    func testSKaupatParseReturnsEmptyOnGarbage() {
        XCTAssertEqual(SKaupatCatalog.parse(Data("nonsense".utf8)).count, 0)
    }

    func testPuuiloParseExtractsPriceImagesAndCategory() {
        let json = """
        {"hits":[{
          "objectID":"10165538","name":"Woima vapaa-ajan akku 55AH",
          "price":{"EUR":{"default":59.9,"default_formated":"59,90"}},
          "image_url":"https://www.puuilo.fi/media/a.png","thumbnail_url":"https://www.puuilo.fi/media/t.png",
          "product_brand":"Woima","categories_without_path":["Vapaa-ajan akut"],"sku":"10165538"
        }]}
        """.data(using: .utf8)!
        let products = PuuiloCatalog.parse(json)
        XCTAssertEqual(products.count, 1)
        let p = products[0]
        XCTAssertEqual(p.name, "Woima vapaa-ajan akku 55AH")
        XCTAssertEqual(p.priceText, "59,90 €")
        XCTAssertEqual(p.brand, "Woima")
        XCTAssertEqual(p.categoryPath, ["Vapaa-ajan akut"])
        XCTAssertEqual(p.imageURLs.count, 1)
    }

    func testPuuiloHandlesOnlyPuuilo() {
        XCTAssertTrue(PuuiloCatalog.handles(storeName: "Puuilo"))
        XCTAssertFalse(PuuiloCatalog.handles(storeName: "Prisma"))
    }

    func testPuuiloKeyExtractionFromEscapedConfig() {
        let html = #"..."applicationId":"HH40ESW4PH","indexName":"puuilo_fi","apiKey":"ABC123secured"..."#
        XCTAssertEqual(PuuiloKey.extractKey(from: Data(html.utf8)), "ABC123secured")
    }

    func testCatalogRegistryRoutesStores() {
        XCTAssertTrue(CatalogRegistry.provider(for: "Prisma") is SKaupatCatalog)
        XCTAssertTrue(CatalogRegistry.provider(for: "Puuilo") is PuuiloCatalog)
        XCTAssertTrue(CatalogRegistry.provider(for: "Tokmanni") is TokmanniCatalog)
        XCTAssertNil(CatalogRegistry.provider(for: "Lidl"))
    }

    func testTokmanniParseExtractsKlevuProduct() {
        let json = """
        {"result":[{
          "id":"643811478006","name":"Akkuporakone CLICK 18 V","sku":"643811478006",
          "price":"59.99","salePrice":"49.99",
          "cloudinary_image":"https://res.cloudinary.com/tokmanni/image/upload/x.jpg",
          "url":"https://www.tokmanni.fi/akkuporakone","category":"akkuporakoneet",
          "item_brand_name":"brücke","shortDesc":"Kevyt akkuporakone"
        }]}
        """.data(using: .utf8)!
        let products = TokmanniCatalog.parse(json)
        XCTAssertEqual(products.count, 1)
        let p = products[0]
        XCTAssertEqual(p.name, "Akkuporakone CLICK 18 V")
        XCTAssertEqual(p.price, 49.99)          // sale price wins
        XCTAssertEqual(p.priceText, "49,99 €")
        XCTAssertEqual(p.brand, "brücke")
        XCTAssertEqual(p.categoryPath, ["akkuporakoneet"])
        XCTAssertEqual(p.description, "Kevyt akkuporakone")
        XCTAssertEqual(p.imageURLs.count, 1)
    }

    func testTokmanniHandlesOnlyTokmanni() {
        XCTAssertTrue(TokmanniCatalog.handles(storeName: "Tokmanni"))
        XCTAssertFalse(TokmanniCatalog.handles(storeName: "Puuilo"))
    }

    func testKRautaParsesProductPriceAndShelfFromEmbeddedHTML() {
        // Mirrors the real Next.js flight data shape: a product record, a
        // price map keyed by EAN, and an availability entry with a real
        // per-store shelfLocation.
        let html = ###"""
        {"id":6438313566311,"ean":"6438313566311","productId":"502140131","name":"Vasara PROF kirvesmiehen taottu 16oz","brand":"PROF","measurements":{},"image":"https://public.keskofiles.com/f/btt/ASSET_JPEG_24767850","images":["x"]}
        ...prices..."6438313566311":{"ean":"6438313566311","type":"ecom","basePrice":19.95,"campaignPrice":19.95,"scales":[],"qualifier":"REGULAR","price":19.95}...
        ...avail..."6438313566311":{"ean":"6438313566311","storeAvailabilities":[{"availability":{"status":"AVAILABLE"},"quantity":4,"shelfLocation":{"location":"Sisämyymälä","locationCode":"S","department":"Työvälineet","departmentCode":"S09","shelfNumber":"7/8","shelfModule":"Moduuli 13"}}]}...
        """###
        let products = KRautaCatalog.parse(html)
        XCTAssertEqual(products.count, 1)
        let p = products[0]
        XCTAssertEqual(p.name, "Vasara PROF kirvesmiehen taottu 16oz")
        XCTAssertEqual(p.price, 19.95)
        XCTAssertEqual(p.priceText, "19,95 €")
        XCTAssertEqual(p.brand, "PROF")
        XCTAssertEqual(p.imageURLs.count, 1)
        XCTAssertEqual(p.shelfLocation, "Työvälineet · hylly 7/8")
    }

    func testKRautaHandlesRautaStores() {
        XCTAssertTrue(KRautaCatalog.handles(storeName: "K-Rauta"))
        XCTAssertFalse(KRautaCatalog.handles(storeName: "Tokmanni"))
    }

    func testMotonetParsesSuggestionsProduct() {
        let json = """
        {"groups":[],"queryUsed":"jarrupala","products":[{
          "id":"98-27478","isVariant":false,"name":"Jarrupalasarja 98-27478",
          "description":"Brembo Carbon-Ceramic","price":"26,90","brand":"BREMBO",
          "categoryName":"Jarrupalat","categoryUrl":"/x"
        }]}
        """.data(using: .utf8)!
        let products = MotonetCatalog.parse(json)
        XCTAssertEqual(products.count, 1)
        let p = products[0]
        XCTAssertEqual(p.name, "Jarrupalasarja 98-27478")
        XCTAssertEqual(p.price, 26.90)
        XCTAssertEqual(p.priceText, "26,90 €")
        XCTAssertEqual(p.brand, "BREMBO")
        XCTAssertEqual(p.categoryPath, ["Jarrupalat"])
        XCTAssertEqual(p.description, "Brembo Carbon-Ceramic")
        XCTAssertEqual(p.imageURLs.first?.absoluteString,
                       "https://cdn.broman.group/api/image/v2/image/motonet/productcode/98-27478/300/300/80/FFFFFF00.webp")
    }

    func testMotonetHandlesOnlyMotonet() {
        XCTAssertTrue(MotonetCatalog.handles(storeName: "Motonet"))
        XCTAssertFalse(MotonetCatalog.handles(storeName: "Puuilo"))
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

    func testCrashReportRoundTripsThroughFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let report = CrashReport(date: Date(timeIntervalSince1970: 1000), version: "9.9.9",
                                 kind: "coredata", name: "TestError",
                                 reason: "store load failed", stack: ["frame0", "frame1"])
        CrashReporter.save(report, to: url)
        let loaded = CrashReporter.load(from: url)
        XCTAssertEqual(loaded?.version, "9.9.9")
        XCTAssertEqual(loaded?.name, "TestError")
        XCTAssertEqual(loaded?.reason, "store load failed")
        XCTAssertEqual(loaded?.stack.count, 2)

        CrashReporter.clear(at: url)
        XCTAssertNil(CrashReporter.load(from: url))
    }

    func testCrashReportSummaryIsHumanReadable() {
        let report = CrashReport(date: Date(timeIntervalSince1970: 0), version: "1.0",
                                 kind: "signal", name: "SIGSEGV",
                                 reason: "segmentation fault", stack: [])
        XCTAssertTrue(report.summary.contains("SIGSEGV"))
        XCTAssertTrue(report.summary.contains("segmentation fault"))
    }

    func testPriceTextFormatsFinnishAndHidesZero() {
        XCTAssertEqual(ShoppingListLogic.priceText(12.5), "12,50 €")
        XCTAssertEqual(ShoppingListLogic.priceText(0.95), "0,95 €")
        XCTAssertNil(ShoppingListLogic.priceText(0))
    }

    func testLineTotalMultipliesPriceByQuantity() throws {
        let container = CoreDataStack.container(inMemory: true)
        let item = CDShoppingItem(context: container.viewContext)
        item.name = "maito"
        item.priceValue = 1.5
        item.quantity = 3
        XCTAssertEqual(item.lineTotal, 4.5, accuracy: 0.0001)
        let free = CDShoppingItem(context: container.viewContext)
        free.name = "leipä"
        XCTAssertEqual(free.lineTotal, 0)   // no price → 0
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
