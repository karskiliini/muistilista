import Foundation

/// One product from a store catalog. Physical shelf location is
/// deliberately absent — no Finnish grocery API exposes it; the app's own
/// family shelf memory supplies that.
struct CatalogProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Double?
    let priceUnit: String
    let comparison: String?
    let categoryPath: [String]
    let brand: String?
    let imageURL: URL?

    var priceText: String? {
        guard let price else { return nil }
        let euros = String(format: "%.2f", price).replacingOccurrences(of: ".", with: ",")
        return "\(euros) €"
    }
}

/// A source of product data for a given store. Kept minimal so more chains
/// (Kesko once its key arrives, etc.) drop in behind the same interface.
protocol CatalogProvider {
    static func handles(storeName: String) -> Bool
    func search(_ query: String) async throws -> [CatalogProduct]
}

/// Picks the provider for a store name, or nil when the store has no
/// catalog (then the manual add path is used).
enum CatalogRegistry {
    static func provider(for storeName: String) -> CatalogProvider? {
        if SKaupatCatalog.handles(storeName: storeName) { return SKaupatCatalog() }
        return nil
    }
}

/// S-group (Prisma / S-market / Sale / Alepa / ABC / Sokos) via the
/// s-kaupat.fi persisted GraphQL query. No API key. Products, categories
/// and images are identical across S-stores; price is from a representative
/// store (`defaultStoreId`) and is indicative.
struct SKaupatCatalog: CatalogProvider {
    /// A large Prisma; overridable if real per-store resolution is added.
    static let defaultStoreId = "513971200"
    private static let productsQueryHash =
        "44ca017dddccfe49e787b483f471f26217adca807f8c71101d11e881dab9e480"
    private static let sGroupNeedles = ["prisma", "s-market", "smarket", "sale",
                                        "alepa", "abc", "sokos", "s-kaupat", "s-market"]

    static func handles(storeName: String) -> Bool {
        let lower = storeName.lowercased()
        return sGroupNeedles.contains { lower.contains($0) }
    }

    static func searchURL(query: String, storeId: String) -> URL? {
        let variables: [String: Any] = [
            "facets": [["key": "brandName", "order": "asc"], ["key": "category"], ["key": "labels"]],
            "fetchSponsoredContent": false,
            "limit": 20,
            "queryString": query,
            "storeId": storeId,
            "useRandomId": false,
        ]
        let extensions: [String: Any] = [
            "persistedQuery": ["version": 1, "sha256Hash": productsQueryHash]
        ]
        func encode(_ object: Any) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: object),
                  let string = String(data: data, encoding: .utf8) else { return nil }
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return string.addingPercentEncoding(withAllowedCharacters: allowed)
        }
        guard let v = encode(variables), let e = encode(extensions) else { return nil }
        return URL(string: "https://api.s-kaupat.fi/?operationName=RemoteFilteredProducts"
                   + "&variables=\(v)&extensions=\(e)")
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        guard let url = Self.searchURL(query: query, storeId: Self.defaultStoreId) else { return [] }
        var request = URLRequest(url: url)
        // The endpoint's WAF only serves browser-shaped requests.
        request.setValue("https://www.s-kaupat.fi", forHTTPHeaderField: "Origin")
        request.setValue("https://www.s-kaupat.fi/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return Self.parse(data)
    }

    static func parse(_ data: Data) -> [CatalogProduct] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let store = (root["data"] as? [String: Any])?["store"] as? [String: Any],
              let products = store["products"] as? [String: Any],
              let items = products["productListItems"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let p = item["product"] as? [String: Any],
                  let id = p["id"] as? String,
                  let name = p["name"] as? String else { return nil }
            let path = (p["hierarchyPath"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
            let image = (((p["productDetails"] as? [String: Any])?["productImages"] as? [String: Any])?["mainImage"] as? [String: Any])?["urlTemplate"] as? String
            let resolvedImage = image?
                .replacingOccurrences(of: "{MODIFIERS}", with: "w_120,h_120,c_fit")
                .replacingOccurrences(of: "{EXTENSION}", with: "png")
            return CatalogProduct(
                id: id,
                name: name,
                price: p["price"] as? Double,
                priceUnit: (p["priceUnit"] as? String) ?? "kpl",
                comparison: {
                    if let cp = p["comparisonPrice"] as? Double, let cu = p["comparisonUnit"] as? String {
                        let e = String(format: "%.2f", cp).replacingOccurrences(of: ".", with: ",")
                        return "\(e) €/\(cu.lowercased())"
                    }
                    return nil
                }(),
                categoryPath: path,
                brand: p["brandName"] as? String,
                imageURL: resolvedImage.flatMap(URL.init(string:)))
        }
    }
}
