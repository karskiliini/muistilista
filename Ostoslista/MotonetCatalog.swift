import Foundation

/// Motonet via its storefront suggestions API. `GET /api/suggestions?q=`
/// returns products with name, price, description, brand and category; the
/// image is built from the product code on the Broman CDN. No key, no
/// shelf location (Motonet's per-store aisle isn't in this response).
struct MotonetCatalog: CatalogProvider {
    static func handles(storeName: String) -> Bool {
        storeName.lowercased().contains("motonet")
    }

    static func searchURL(query: String) -> URL? {
        var c = URLComponents(string: "https://www.motonet.fi/api/suggestions")
        c?.queryItems = [.init(name: "q", value: query)]
        return c?.url
    }

    static func imageURL(code: String) -> URL? {
        URL(string: "https://cdn.broman.group/api/image/v2/image/motonet/productcode/\(code)/300/300/80/FFFFFF00.webp")
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        guard let url = Self.searchURL(query: query) else { return [] }
        let (data, _) = try await URLSession.shared.data(
            for: CatalogHTTP.request(url, origin: "https://www.motonet.fi"))
        return Self.parse(data)
    }

    static func parse(_ data: Data) -> [CatalogProduct] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = root["products"] as? [[String: Any]] else { return [] }
        return products.compactMap { p in
            guard let id = p["id"] as? String, let name = p["name"] as? String else { return nil }
            // price arrives as a Finnish-formatted string, e.g. "26,90".
            let priceString = p["price"] as? String
            let price = priceString.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
            let category = (p["categoryName"] as? String).map { [$0] } ?? []
            let desc = (p["description"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return CatalogProduct(
                id: id, name: name,
                price: price, priceFormatted: priceString,
                comparison: nil, categoryPath: category,
                brand: (p["brand"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                imageURLs: [imageURL(code: id)].compactMap { $0 },
                description: desc, shelfLocation: nil)
        }
    }
}
