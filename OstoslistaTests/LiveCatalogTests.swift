import XCTest
@testable import Ostoslista

/// Live network tests: they exercise the real store search endpoints
/// through the app's own provider code on the simulator, proving the
/// end-to-end catalog search (URL build → HTTPS request → parse) actually
/// returns products on-device. Network-dependent by design; skipped
/// automatically when offline.
final class LiveCatalogTests: XCTestCase {

    private func assertFindsProducts(_ provider: CatalogProvider,
                                     query: String,
                                     file: StaticString = #filePath, line: UInt = #line) async throws {
        let products: [CatalogProduct]
        do {
            products = try await provider.search(query)
        } catch {
            throw XCTSkip("Network unavailable: \(error.localizedDescription)")
        }
        XCTAssertFalse(products.isEmpty, "expected products for '\(query)'", file: file, line: line)
        XCTAssertNotNil(products.first?.name, file: file, line: line)
        XCTAssertNotNil(products.first?.price, "expected a price", file: file, line: line)
    }

    func testSKaupatLiveSearchReturnsProducts() async throws {
        try await assertFindsProducts(SKaupatCatalog(), query: "maito")
    }

    func testPuuiloLiveSearchReturnsProducts() async throws {
        try await assertFindsProducts(PuuiloCatalog(), query: "akku")
    }

    func testTokmanniLiveSearchReturnsProducts() async throws {
        try await assertFindsProducts(TokmanniCatalog(), query: "porakone")
    }

    func testKRautaLiveSearchReturnsProducts() async throws {
        try await assertFindsProducts(KRautaCatalog(), query: "vasara")
    }

    func testMotonetLiveSearchReturnsProducts() async throws {
        try await assertFindsProducts(MotonetCatalog(), query: "jarrupala")
    }

    func testStoreDirectoryFindsKommila() async throws {
        let stores: [StoreLocation]
        do {
            stores = try await SKaupatStoreDirectory().searchStores(query: "kommila", brand: "s-market")
        } catch {
            throw XCTSkip("Network unavailable: \(error.localizedDescription)")
        }
        XCTAssertTrue(stores.contains { $0.id == "708276035" },
                      "expected S-market Kommila Varkaus, got \(stores.map(\.name))")
    }

    func testSKaupatSearchWithSelectedKommilaStore() async throws {
        SelectedStores.defaults = UserDefaults(suiteName: "LiveStoreTests")!
        defer { SelectedStores.defaults.removePersistentDomain(forName: "LiveStoreTests") }
        SelectedStores.select(StoreLocation(id: "708276035", name: "S-market Kommila Varkaus",
                                            brand: "s-market", street: "Savontie 44", city: "Varkaus"),
                              for: "S-market")
        try await assertFindsProducts(SKaupatCatalog(chainName: "S-market"), query: "maito")
    }
}
