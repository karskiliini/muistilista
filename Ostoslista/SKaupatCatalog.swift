import Foundation

/// S-group (Prisma / S-market / Sale / Alepa / ABC) via the s-kaupat.fi
/// persisted GraphQL query. No API key. Products, categories and images are
/// identical across S-stores; price is from a representative store and is
/// indicative. Grocery has no shelf location — category only.
struct SKaupatCatalog: CatalogProvider {
    static let defaultStoreId = "513971200"
    private static let productsQueryHash =
        "44ca017dddccfe49e787b483f471f26217adca807f8c71101d11e881dab9e480"
    private static let sGroupNeedles = ["prisma", "s-market", "smarket", "sale",
                                        "alepa", "abc", "sokos", "s-kaupat"]

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
        let (data, _) = try await URLSession.shared.data(
            for: CatalogHTTP.request(url, origin: "https://www.s-kaupat.fi"))
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
            let resolved = image?
                .replacingOccurrences(of: "{MODIFIERS}", with: "w_240,h_240,c_fit")
                .replacingOccurrences(of: "{EXTENSION}", with: "png")
            let comparison: String? = {
                if let cp = p["comparisonPrice"] as? Double, let cu = p["comparisonUnit"] as? String {
                    let e = String(format: "%.2f", cp).replacingOccurrences(of: ".", with: ",")
                    return "\(e) €/\(cu.lowercased())"
                }
                return nil
            }()
            return CatalogProduct(
                id: id, name: name,
                price: p["price"] as? Double, priceFormatted: nil,
                comparison: comparison, categoryPath: path,
                brand: p["brandName"] as? String,
                imageURLs: [resolved].compactMap { $0 }.compactMap(URL.init(string:)),
                description: nil, shelfLocation: nil)
        }
    }
}
