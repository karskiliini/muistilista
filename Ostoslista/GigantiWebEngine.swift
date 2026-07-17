import Foundation
import WebKit

/// Gigantti (gigantti.fi) sits behind Vercel's bot challenge, so a plain
/// URLSession is blocked (429). A hidden WKWebView passes the challenge like
/// Safari does; each search then runs INSIDE the page: it fetches a short-lived
/// signed Algolia key from the site's own endpoint (only reachable in the
/// challenge-passed page context) and queries Algolia directly. If anything
/// breaks — challenge tightens, endpoint changes, no network — `status` becomes
/// `.unavailable` and the UI simply says Gigantti data isn't available.
@MainActor
final class GigantiWebEngine: NSObject, ObservableObject {
    static let shared = GigantiWebEngine()

    enum Status: Equatable { case idle, warming, ready, unavailable }
    @Published private(set) var status: Status = .idle

    private var webView: WKWebView?
    private var navContinuation: CheckedContinuation<Void, Error>?

    /// Called once at app startup so the first real search is fast.
    func warmUp() {
        guard status == .idle else { return }
        status = .warming
        let web = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1))
        web.navigationDelegate = self
        web.isHidden = true
        web.alpha = 0
        attach(web)
        webView = web

        Task {
            do {
                try await load("https://www.gigantti.fi/")
                // The bot challenge resolves after the first load; confirm it by
                // fetching a signed key before declaring the engine ready.
                for _ in 0..<40 {
                    let js = "try{const k=await fetch('/api/algolia/signed-api-key',{headers:{accept:'application/json'}}).then(r=>r.json());return !!(k&&k.apiKey);}catch(e){return false;}"
                    if let ok = try? await web.callAsyncJavaScript(
                        js, arguments: [:], in: nil, contentWorld: .page) as? Bool, ok {
                        status = .ready
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                }
                status = .unavailable
            } catch {
                status = .unavailable
            }
        }
    }

    /// Off-screen, invisible web view added to the key window so the challenge
    /// JS and timers run (Vercel needs a live view, like Cloudflare).
    private func attach(_ web: WKWebView) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
        scene?.windows.first?.addSubview(web)
    }

    /// Products, or nil when Gigantti is unavailable (never throws so callers
    /// can distinguish "no data source" from "no hits").
    func search(_ query: String) async -> [GigantiProduct]? {
        if status == .idle { warmUp() }
        for _ in 0..<48 where status == .warming {
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard status == .ready, let web = webView else { return nil }
        do {
            let raw = try await web.callAsyncJavaScript(
                Self.searchJS, arguments: ["q": query], in: nil, contentWorld: .page)
            guard let json = raw as? String, let data = json.data(using: .utf8),
                  let capture = try? JSONDecoder().decode(GigantiCapture.self, from: data)
            else { return [] }
            return capture.products
        } catch {
            status = .unavailable
            return nil
        }
    }

    private func load(_ urlString: String) async throws {
        guard let web = webView, let url = URL(string: urlString) else {
            throw CatalogError.unavailable
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            navContinuation = cont
            web.load(URLRequest(url: url))
        }
    }

    /// Runs in the page context: fetch a signed key, query Algolia's product
    /// index, and return normalized hits as JSON. `q` is the search query.
    private static let searchJS = """
    let apiKey;
    try {
      const k = await fetch('/api/algolia/signed-api-key', {headers:{accept:'application/json'}}).then(r=>r.json());
      apiKey = k && k.apiKey;
    } catch(e) {}
    if (!apiKey) return JSON.stringify({query:q, products:[]});
    let hits = [];
    try {
      const r = await fetch('https://z0fl7r8ubh-dsn.algolia.net/1/indexes/commerce_b2c_OCFIGIG/query', {
        method:'POST',
        headers:{'x-algolia-application-id':'Z0FL7R8UBH','x-algolia-api-key':apiKey,'content-type':'application/json'},
        body: JSON.stringify({query:q, hitsPerPage:12})
      }).then(r=>r.json());
      hits = (r.hits||[]).filter(h=>h.isBuyableOnline!==false).map(h=>({
        id: String(h.objectID||''),
        name: h.title || h.name || '',
        brand: (typeof h.brand==='string') ? h.brand : null,
        price: (h.price && typeof h.price.amount==='number') ? h.price.amount : null,
        image: (typeof h.imageUrl==='string') ? h.imageUrl : null,
        url: (typeof h.url==='string') ? h.url : ((typeof h.productUrl==='string') ? h.productUrl : null),
        desc: (typeof h.shortDescription==='string') ? h.shortDescription : null
      })).filter(x=>x.name);
    } catch(e) {}
    return JSON.stringify({query:q, products:hits});
    """
}

extension GigantiWebEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navContinuation?.resume(); navContinuation = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navContinuation?.resume(throwing: error); navContinuation = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navContinuation?.resume(throwing: error); navContinuation = nil
    }
}

/// A normalized product from the Gigantti Algolia query.
struct GigantiProduct: Decodable {
    let id: String
    let name: String
    let brand: String?
    let price: Double?
    let image: String?
    let url: String?
    let desc: String?
}

private struct GigantiCapture: Decodable {
    let query: String
    let products: [GigantiProduct]
}
