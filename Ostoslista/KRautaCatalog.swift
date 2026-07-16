import Foundation

/// K-Rauta has no clean product API, but its search results page is
/// server-rendered with all product data embedded (Next.js flight data):
/// product records, prices keyed by EAN, and — uniquely — real per-store
/// shelf locations (department + shelf number). So the app fetches the
/// search HTML once and parses it. Heavier than a JSON API (the page is
/// large), but it's a single request, needs no key, and yields the real
/// aisle no grocery API exposes.
struct KRautaCatalog: CatalogProvider {
    static func handles(storeName: String) -> Bool {
        storeName.lowercased().contains("rauta")
    }

    func search(_ query: String) async throws -> [CatalogProduct] {
        var components = URLComponents(string: "https://www.k-rauta.fi/etsi")
        components?.queryItems = [.init(name: "query", value: query)]
        guard let url = components?.url else { return [] }
        var request = CatalogHTTP.request(url, origin: "https://www.k-rauta.fi")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return Self.parse(html)
    }

    static func parse(_ html: String) -> [CatalogProduct] {
        let prices = matches(in: html,
            #"\"(\d{8,14})\":\{\"ean\":\"\1\",\"type\":\"[^\"]*\"[^{}]*?\"price\":([0-9.]+)"#)
            .reduce(into: [String: Double]()) { dict, m in
                if let p = Double(m.1) { dict[m.0] = p }
            }
        let shelves = shelfLocations(in: html)

        // Product records: {"id":..,"ean":"..","productId":"..","name":"..","brand":".."...,"image":".."}
        // (a "measurements":{} object can sit between brand and image, so
        // allow braces in the gap but bound it to stay within one record.)
        let pattern = #"\{\"id\":\d+,\"ean\":\"(\d{8,14})\",\"productId\":\"[^\"]*\",\"name\":\"([^\"]+)\",\"brand\":\"([^\"]*)\"[\s\S]{0,200}?\"image\":\"([^\"]+)\""#
        var seen = Set<String>()
        var products: [CatalogProduct] = []
        for m in matches4(in: html, pattern) {
            let (ean, name, brand, image) = m
            guard seen.insert(ean).inserted else { continue }
            products.append(CatalogProduct(
                id: ean,
                name: name.decodingJSONEscapes(),
                price: prices[ean],
                priceFormatted: nil,
                comparison: nil,
                categoryPath: [],
                brand: brand.isEmpty ? nil : brand.decodingJSONEscapes(),
                imageURLs: [URL(string: image)].compactMap { $0 },
                description: nil,
                shelfLocation: shelves[ean]))
        }
        return products
    }

    /// EAN → "Osasto · hylly N" from the first store's shelfLocation.
    private static func shelfLocations(in html: String) -> [String: String] {
        let pattern = #"\"(\d{8,14})\":\{\"ean\":\"\1\",\"storeAvailabilities\":\[\{[\s\S]{0,600}?\"shelfLocation\":\{\"location\":\"[^\"]*\",\"locationCode\":\"[^\"]*\",\"department\":\"([^\"]*)\"[^{}]*?\"shelfNumber\":\"([^\"]*)\""#
        var out: [String: String] = [:]
        guard let re = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = html as NSString
        re.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, match.numberOfRanges >= 4 else { return }
            let ean = ns.substring(with: match.range(at: 1))
            let dept = ns.substring(with: match.range(at: 2))
            let shelf = ns.substring(with: match.range(at: 3))
            let parts = [dept, shelf.isEmpty ? nil : "hylly \(shelf)"].compactMap { $0 }.filter { !$0.isEmpty }
            if !parts.isEmpty { out[ean] = parts.joined(separator: " · ") }
        }
        return out
    }

    // MARK: - Regex helpers

    private static func matches(in text: String, _ pattern: String) -> [(String, String)] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard m.numberOfRanges >= 3 else { return nil }
            return (ns.substring(with: m.range(at: 1)), ns.substring(with: m.range(at: 2)))
        }
    }

    private static func matches4(in text: String, _ pattern: String) -> [(String, String, String, String)] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard m.numberOfRanges >= 5 else { return nil }
            return (ns.substring(with: m.range(at: 1)), ns.substring(with: m.range(at: 2)),
                    ns.substring(with: m.range(at: 3)), ns.substring(with: m.range(at: 4)))
        }
    }
}

private extension String {
    /// Decode the common JSON string escapes that survive in the raw HTML.
    func decodingJSONEscapes() -> String {
        guard let data = "\"\(self)\"".data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data) else { return self }
        return decoded
    }
}
