import Foundation

/// One product from a store catalog. `shelfLocation` is present only for
/// chains that publish a real aisle; grocery chains leave it nil and the
/// app's family shelf memory supplies it. `description` is present only
/// when the chain's search index carries one.
struct CatalogProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Double?
    let priceFormatted: String?
    let comparison: String?
    let categoryPath: [String]
    let brand: String?
    let imageURLs: [URL]
    var description: String? = nil
    var shelfLocation: String? = nil

    var imageURL: URL? { imageURLs.first }

    /// "59,90 €" — formatted string from the chain if given, else derived.
    var priceText: String? {
        if let priceFormatted { return "\(priceFormatted) €" }
        guard let price else { return nil }
        return String(format: "%.2f", price).replacingOccurrences(of: ".", with: ",") + " €"
    }
}

/// A source of product data for a store. New chains drop in behind this.
protocol CatalogProvider {
    static func handles(storeName: String) -> Bool
    func search(_ query: String) async throws -> [CatalogProduct]
}

/// Picks the provider for a store name, or nil when the store has no
/// catalog yet (then the manual add path is used).
enum CatalogRegistry {
    static func provider(for storeName: String) -> CatalogProvider? {
        if SKaupatCatalog.handles(storeName: storeName) { return SKaupatCatalog() }
        if PuuiloCatalog.handles(storeName: storeName) { return PuuiloCatalog() }
        if TokmanniCatalog.handles(storeName: storeName) { return TokmanniCatalog() }
        return nil
    }
}

/// Shared browser-shaped request helper — the store endpoints only answer
/// requests that look like they came from a browser.
enum CatalogHTTP {
    static func request(_ url: URL, origin: String) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue(origin, forHTTPHeaderField: "Origin")
        r.setValue(origin + "/", forHTTPHeaderField: "Referer")
        r.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                   forHTTPHeaderField: "User-Agent")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        return r
    }
}
