import Foundation

/// Tokmanni via its Klevu hosted search (cluster eucs11). Public API key,
/// GET request. Returns name, price, image, brand and category (no shelf
/// location). Description isn't in the Klevu response, so it stays nil.
struct TokmanniCatalog: CatalogProvider {
    private static let host = "eucs11.ksearchnet.com"
    private static let apiKey = "klevu-15488592134928913"

    static func handles(storeName: String) -> Bool {
        storeName.lowercased().contains("tokmanni")
    }

    static func searchURL(query: String) -> URL? {
        var components = URLComponents(string: "https://\(host)/cloud-search/n-search/search")
        components?.queryItems = [
            .init(name: "ticket", value: apiKey),
            .init(name: "term", value: query),
            .init(name: "noOfResults", value: "20"),
            .init(name: "paginationStartsFrom", value: "0"),
            .init(name: "responseType", value: "json"),
            .init(name: "sv", value: "2.2.5"),
            .init(name: "enableFilters", value: "false"),
            .init(name: "klevuFetchPopularTerms", value: "false"),
        ]
        return components?.url
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        guard let url = Self.searchURL(query: query) else { return [] }
        let (data, _) = try await URLSession.shared.data(
            for: CatalogHTTP.request(url, origin: "https://www.tokmanni.fi"))
        return Self.parse(data)
    }

    static func parse(_ data: Data) -> [CatalogProduct] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [[String: Any]] else { return [] }
        return result.compactMap { p in
            guard let name = p["name"] as? String else { return nil }
            let id = (p["id"] as? String) ?? (p["sku"] as? String) ?? name
            // Klevu prices arrive as strings like "49.99".
            let price = (p["salePrice"] as? String).flatMap(Double.init)
                ?? (p["price"] as? String).flatMap(Double.init)
            let image = ["cloudinary_image", "imageUrl", "image"]
                .compactMap { p[$0] as? String }.first { !$0.isEmpty }
            let category = (p["category"] as? String).map { [$0] } ?? []
            let desc = (p["shortDesc"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return CatalogProduct(
                id: id, name: name,
                price: price, priceFormatted: nil,
                comparison: nil, categoryPath: category,
                brand: (p["item_brand_name"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                imageURLs: [image].compactMap { $0 }.compactMap(URL.init(string:)),
                description: desc, shelfLocation: nil)
        }
    }
}
