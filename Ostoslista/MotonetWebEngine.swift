import Foundation
import WebKit

/// Motonet's shelf location ("Hyllypaikka 63") is only in the server-rendered
/// product page, and only once a store is selected — the selection is a
/// server action that sets an httpOnly cookie, so a plain URLSession can't do
/// it. This isolated engine uses WebKit: the user picks their Motonet store
/// once in a real Motonet web view (with Motonet's own nearest-store button),
/// which persists the cookie; then a hidden web view reads the shelf from
/// product pages. All Motonet-shelf complexity lives here.
@MainActor
final class MotonetWebEngine: NSObject, ObservableObject {
    static let shared = MotonetWebEngine()

    /// Persisted store name so we can tell the user which store is in use and
    /// let them change it. The cookie itself lives in the shared WKWebView
    /// data store (persistent across launches). Published so views update.
    @Published var storeName: String = UserDefaults.standard.string(forKey: "motonetStoreName") ?? "" {
        didSet { UserDefaults.standard.set(storeName, forKey: "motonetStoreName") }
    }
    var hasStore: Bool { !storeName.isEmpty }

    /// The URL to show in the selection sheet — Motonet's own store picker.
    static let storeSelectorURL = URL(string: "https://www.motonet.fi/fi/tavaratalot")!

    private var webView: WKWebView?
    private var navContinuation: CheckedContinuation<Void, Error>?
    private var cache: [String: String] = [:]   // productCode → shelf

    /// Shelf text for a product code, or nil (no store / not found / error).
    /// Only called from the product detail view, so one fetch per inspected
    /// product — not per search result.
    func shelf(forProductCode code: String) async -> String? {
        guard hasStore else { return nil }
        if let cached = cache[code] { return cached }
        let web = ensureWebView()
        // Any slug works; the ?product= code drives which product loads.
        guard let url = URL(string: "https://www.motonet.fi/fi/tuote/x?product=\(code)") else { return nil }
        do {
            try await load(url, in: web)
        } catch { return nil }
        // Give the store-scoped content a moment, then read the shelf text.
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(250))
            let js = """
            (function(){var t=document.body?document.body.innerText:'';
             var m=t.match(/Hyllypaikka[^\\n]{0,40}/i); return m?m[0].trim():'';})()
            """
            if let text = (try? await web.evaluateJavaScript(js)) as? String, !text.isEmpty {
                cache[code] = text
                return text
            }
        }
        return nil
    }

    private func ensureWebView() -> WKWebView {
        if let webView { return webView }
        // Default data store → shares the persistent cookie set by the
        // selection sheet.
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let web = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: config)
        web.navigationDelegate = self
        web.isHidden = true
        web.alpha = 0
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?
            .windows.first?.addSubview(web)
        webView = web
        return web
    }

    /// The selection sheet calls this once the user has chosen a store, so we
    /// remember its name and drop any stale shelf cache.
    func didSelectStore(named name: String) {
        storeName = name
        cache.removeAll()
    }

    private func load(_ url: URL, in web: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            navContinuation = cont
            web.load(URLRequest(url: url))
        }
    }
}

extension MotonetWebEngine: WKNavigationDelegate {
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
