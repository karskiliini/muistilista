import Foundation

/// Thin CatalogProvider that delegates to the isolated WKWebView engine.
/// Handles the K-ruoka grocery chains (K-Citymarket / K-Supermarket /
/// K-Market). Returns [] with the engine unavailable — the store-add view
/// checks `KRuokaWebEngine.status` to show the "not available" message.
struct KRuokaCatalog: CatalogProvider {
    static func handles(storeName: String) -> Bool {
        let s = storeName.lowercased()
        return s.contains("k-citymarket") || s.contains("k-supermarket") || s.contains("k-market")
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        let products = await KRuokaWebEngine.shared.search(query)
        guard let products else { throw CatalogError.unavailable }
        return products.map { p in
            CatalogProduct(
                id: p.id, name: p.name,
                price: p.price, priceFormatted: nil,
                comparison: p.comparison,
                categoryPath: p.category.map { [$0] } ?? [],
                brand: p.brand,
                imageURLs: [p.image].compactMap { $0 }.compactMap(URL.init(string:)),
                description: nil, shelfLocation: nil)
        }
    }
}
