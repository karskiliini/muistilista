import Foundation

/// Thin CatalogProvider that delegates to the isolated WKWebView engine.
/// Handles Gigantti (electronics). Returns [] when the engine is unavailable —
/// the store-add view's search spinner covers the brief warm-up.
struct GigantiCatalog: CatalogProvider {
    static func handles(storeName: String) -> Bool {
        storeName.lowercased().contains("gigantti")
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        let products = await GigantiWebEngine.shared.search(query)
        guard let products else { throw CatalogError.unavailable }
        return products.map { p in
            // Prefix the brand when the name doesn't already start with it.
            let name: String = {
                guard let b = p.brand, !b.isEmpty,
                      !p.name.lowercased().hasPrefix(b.lowercased()) else { return p.name }
                return "\(b) \(p.name)"
            }()
            return CatalogProduct(
                id: p.id, name: name,
                price: p.price, priceFormatted: nil,
                comparison: nil,
                categoryPath: [],
                brand: p.brand,
                imageURLs: [p.image].compactMap { $0 }.compactMap { URL(string: $0) },
                description: p.desc, shelfLocation: nil)
        }
    }
}
