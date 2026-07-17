import Foundation

/// Puuilo via its Algolia search index. Puuilo's public Algolia key is a
/// *secured, time-limited* key (expires ~weekly), so it can't be hardcoded
/// — the app scrapes the current key off any Puuilo page and caches it,
/// refreshing when Algolia rejects an expired one. Returns name, price,
/// images, brand, category (no shelf location).
struct PuuiloCatalog: CatalogProvider {
    private static let appId = "HH40ESW4PH"
    private static let index = "puuilo_fi_products"

    static func handles(storeName: String) -> Bool {
        storeName.lowercased().contains("puuilo")
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        let key = try await PuuiloKey.shared.current()
        do {
            return Self.parse(try await Self.query(query, key: key))
        } catch CatalogError.unauthorized {
            // Key expired — refresh once and retry.
            let fresh = try await PuuiloKey.shared.refresh()
            return Self.parse(try await Self.query(query, key: fresh))
        }
    }

    private static func query(_ query: String, key: String) async throws -> Data {
        let url = URL(string: "https://\(appId)-dsn.algolia.net/1/indexes/\(index)/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(appId, forHTTPHeaderField: "X-Algolia-Application-Id")
        request.setValue(key, forHTTPHeaderField: "X-Algolia-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["query": query, "hitsPerPage": 20])
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 403 { throw CatalogError.unauthorized }
        return data
    }

    static func parse(_ data: Data) -> [CatalogProduct] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = root["hits"] as? [[String: Any]] else { return [] }
        return hits.compactMap { hit in
            guard let name = hit["name"] as? String else { return nil }
            let id = (hit["objectID"] as? String) ?? (hit["sku"] as? String) ?? name
            let eur = (hit["price"] as? [String: Any])?["EUR"] as? [String: Any]
            let images = ["image_url", "thumbnail_url"]
                .compactMap { hit[$0] as? String }
                .compactMap(URL.init(string:))
            let category = (hit["categories_without_path"] as? [String])
                ?? ((hit["categories"] as? [String: Any])?["level0"] as? [String]) ?? []
            return CatalogProduct(
                id: id, name: name,
                price: eur?["default"] as? Double,
                priceFormatted: eur?["default_formated"] as? String,
                comparison: nil, categoryPath: category,
                brand: hit["product_brand"] as? String,
                imageURLs: Array(images.prefix(1)),
                description: hit["short_description"] as? String ?? hit["description"] as? String,
                shelfLocation: nil)
        }
    }
}

enum CatalogError: Error { case unauthorized, unavailable }

/// Caches Puuilo's rotating Algolia key across searches; scrapes a fresh
/// one from the site when missing or expired. Actor-isolated so concurrent
/// searches share one fetch.
actor PuuiloKey {
    static let shared = PuuiloKey()
    private var cached: String?

    func current() async throws -> String {
        if let cached { return cached }
        return try await refresh()
    }

    func refresh() async throws -> String {
        let url = URL(string: "https://www.puuilo.fi/")!
        let (data, _) = try await URLSession.shared.data(
            for: CatalogHTTP.request(url, origin: "https://www.puuilo.fi"))
        guard let key = Self.extractKey(from: data) else { throw CatalogError.unauthorized }
        cached = key
        return key
    }

    /// The site embeds the config unicode-escaped; decode then regex it out.
    static func extractKey(from data: Data) -> String? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let decoded = raw.applyingUnicodeEscapes()
        let pattern = "\"applicationId\":\"HH40ESW4PH\",\"indexName\":\"puuilo_fi\",\"apiKey\":\"([^\"]+)\""
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: decoded, range: NSRange(decoded.startIndex..., in: decoded)),
              let r = Range(m.range(at: 1), in: decoded) else { return nil }
        return String(decoded[r])
    }
}

private extension String {
    /// Turn / etc. into real characters (the site double-escapes JSON).
    func applyingUnicodeEscapes() -> String {
        guard contains("\\u") else { return self }
        var result = ""
        var i = startIndex
        while i < endIndex {
            if self[i] == "\\", index(i, offsetBy: 1, limitedBy: endIndex).map({ $0 < endIndex && self[$0] == "u" }) == true {
                let hexStart = index(i, offsetBy: 2)
                if let hexEnd = index(hexStart, offsetBy: 4, limitedBy: endIndex),
                   let code = UInt32(self[hexStart..<hexEnd], radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    result.unicodeScalars.append(scalar)
                    i = hexEnd
                    continue
                }
            }
            result.append(self[i])
            i = index(after: i)
        }
        return result
    }
}
