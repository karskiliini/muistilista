import Foundation

/// One physical store of an S-group chain, from the s-kaupat.fi store
/// directory. `brand` is the chain in the directory's own lowercase form
/// ("s-market", "prisma", …).
struct StoreLocation: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let brand: String
    let street: String
    let city: String
}

/// Store directory scraped from s-kaupat.fi's server-rendered /myymalat
/// page (no API key; the client-side GraphQL op is lazy-loaded and its
/// persisted hash unreachable, but SSR embeds full StoreInfo records).
struct SKaupatStoreDirectory {
    /// App chain name (Stores.swift) → directory brand. Only these chains
    /// have store-specific catalogs (R36).
    static let chainBrands: [String: String] = [
        "Prisma": "prisma", "S-market": "s-market", "Sale": "sale",
        "Alepa": "alepa", "ABC": "abc",
    ]

    static func parse(_ html: String) -> [StoreLocation] {
        var result: [StoreLocation] = []
        var seen = Set<String>()
        let marker = "{\"__typename\":\"StoreInfo\","
        var search = html.startIndex..<html.endIndex
        while let found = html.range(of: marker, range: search) {
            search = found.upperBound..<html.endIndex
            // Fields live near the record start; a bounded window keeps the
            // regexes from crossing into the next record's data.
            let end = html.index(found.lowerBound, offsetBy: 1500,
                                 limitedBy: html.endIndex) ?? html.endIndex
            let window = String(html[found.lowerBound..<end])
            func capture(_ pattern: String) -> String? {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let m = regex.firstMatch(in: window, range: NSRange(window.startIndex..., in: window)),
                      m.numberOfRanges > 1,
                      let r = Range(m.range(at: 1), in: window) else { return nil }
                return String(window[r])
            }
            guard let id = capture("\"id\":\"([0-9]+)\""),
                  let name = capture("\"name\":\"([^\"]*)\""),
                  let brand = capture("\"brand\":\"([^\"]*)\""),
                  !seen.contains(id) else { continue }
            seen.insert(id)
            let street = capture("\"street\":\\{\"__typename\":\"LocalizableText\",\"default\":\"([^\"]*)\"") ?? ""
            let city = capture("\"postcodeName\":\\{\"__typename\":\"LocalizableText\",\"default\":\"([^\"]*)\"") ?? ""
            result.append(StoreLocation(id: id, name: name, brand: brand, street: street, city: city))
        }
        return result
    }

    /// Live search; `brand` (chainBrands value) filters to one chain.
    func searchStores(query: String, brand: String?) async throws -> [StoreLocation] {
        var comps = URLComponents(string: "https://www.s-kaupat.fi/myymalat")!
        comps.queryItems = [URLQueryItem(name: "query", value: query)]
        var request = URLRequest(url: comps.url!)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let all = Self.parse(String(decoding: data, as: UTF8.self))
        guard let brand else { return all }
        return all.filter { $0.brand == brand }
    }
}
