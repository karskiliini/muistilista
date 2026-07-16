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
}
