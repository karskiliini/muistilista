import Foundation
import WebKit
import CoreLocation

/// All K-ruoka complexity is isolated here. k-ruoka.fi sits behind
/// Cloudflare, so a plain URLSession can't reach it — but a real WebKit
/// engine passes the challenge like Safari does. This drives a hidden
/// WKWebView: it warms up at launch, picks the nearest store from the
/// device location, and reads product-search results the page fetches
/// (captured by a document-start hook). If anything breaks — Cloudflare
/// tightens, the page changes, no network — `status` becomes `.unavailable`
/// and the UI simply says K-ruoka data isn't available right now.
@MainActor
final class KRuokaWebEngine: NSObject, ObservableObject {
    static let shared = KRuokaWebEngine()

    enum Status: Equatable { case idle, warming, ready, unavailable }
    @Published private(set) var status: Status = .idle

    private var webView: WKWebView?
    private var navContinuation: CheckedContinuation<Void, Error>?
    private var storeSelected = false

    // MARK: Setup

    /// Called once at app startup so the first real search is fast.
    func warmUp() {
        guard status == .idle else { return }
        status = .warming
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.hookJS,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let web = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: config)
        web.navigationDelegate = self
        web.isHidden = true
        web.alpha = 0
        attach(web)
        webView = web

        Task {
            do {
                try await load("https://www.k-ruoka.fi/kauppa")
                status = .ready
                await selectNearestStore()
            } catch {
                status = .unavailable
            }
        }
    }

    /// Adds the web view to the key window so it renders (Cloudflare's JS
    /// and timers need a live view); off-screen and invisible.
    private func attach(_ web: WKWebView) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
        scene?.windows.first?.addSubview(web)
    }

    // MARK: Search

    /// Returns products, or nil when K-ruoka is unavailable (never throws so
    /// callers can distinguish "no data source" from "no hits").
    func search(_ query: String) async -> [KRuokaProduct]? {
        guard status == .ready, let web = webView else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        do {
            try await load("https://www.k-ruoka.fi/kauppa/tuotehaku?haku=\(encoded)")
        } catch {
            status = .unavailable
            return nil
        }
        // Poll the hook's capture for up to ~8 s.
        for _ in 0..<32 {
            try? await Task.sleep(for: .milliseconds(250))
            let js = "JSON.stringify(window.__krProducts||null)"
            if let raw = (try? await web.evaluateJavaScript(js)) as? String,
               let data = raw.data(using: .utf8),
               let capture = try? JSONDecoder().decode(KRuokaCapture.self, from: data),
               capture.query.lowercased().contains(query.lowercased().prefix(3)) {
                return capture.products
            }
        }
        return []   // page loaded but no results captured → treat as no hits
    }

    // MARK: Nearest store (location)

    private func selectNearestStore() async {
        guard let web = webView, let loc = try? await LocationOnce.current() else { return }
        // The stores endpoint answers injected fetches from the page context
        // (unlike product-search), so we can pick the nearest here.
        let js = """
        try{
          const r = await fetch('/kr-api/stores/search', {method:'POST',
            headers:{'Content-Type':'application/json','Accept':'application/json'},
            body: JSON.stringify({latitude:\(loc.latitude), longitude:\(loc.longitude)})});
          const j = await r.json();
          const stores = (j.results||[]).filter(s=>s.isWebStore && /kcm|ksm|kmarket/.test(s.chainAbbreviation||''));
          return stores.length ? stores[0].slug : null;
        }catch(e){ return null; }
        """
        if let slug = (try? await web.callAsyncJavaScript(js, arguments: [:], in: nil, contentWorld: .page)) as? String,
           !slug.isEmpty {
            _ = try? await load("https://www.k-ruoka.fi/kauppa/\(slug)")
            storeSelected = true
        }
    }

    // MARK: Navigation helper

    private func load(_ urlString: String) async throws {
        guard let web = webView, let url = URL(string: urlString) else {
            throw CatalogError.unavailable
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            navContinuation = cont
            web.load(URLRequest(url: url))
        }
    }

    private static let hookJS = """
    (function(){
      if(window.__olHook) return; window.__olHook=true; window.__krProducts=null;
      var of=window.fetch;
      window.fetch=function(){
        var args=arguments, p=of.apply(this,args);
        try{
          var u=(typeof args[0]==='string')?args[0]:(args[0]&&args[0].url);
          if(u && u.indexOf('/kr-api/v2/product-search/')>=0 && u.indexOf('suggestions')<0){
            p.then(function(r){return r.clone().json();}).then(function(j){
              var arr=j.result||[];
              var out=arr.map(function(row){
                var pr=row.product||row;
                var name=(pr.localizedName&&pr.localizedName.finnish)||pr.name||'';
                var price=null, comp=null;
                try{var n=pr.pricing&&pr.pricing.normal; if(n){ if(typeof n.price==='number')price=n.price;
                  if(n.unitPrice&&typeof n.unitPrice.value==='number')comp=(''+n.unitPrice.value).replace('.',',')+' \\u20ac/'+(n.unitPrice.unit||''); }}catch(e){}
                var ean=pr.ean||pr.id||'';
                var image=null;
                try{ image=(pr.image&&pr.image.url)||(pr.images&&pr.images[0]&&(pr.images[0].url||pr.images[0]))||(ean?('https://public.keskofiles.com/f/k-ruoka/product/'+ean):null); }catch(e){ if(ean)image='https://public.keskofiles.com/f/k-ruoka/product/'+ean; }
                var cat=''; try{var t=pr.category&&pr.category.tree; if(t&&t.length)cat=(t[t.length-1].localizedName&&t[t.length-1].localizedName.finnish)||'';}catch(e){}
                var brand=null; try{ var b=pr.brand; brand=(b&&(b.name||b)); if(typeof brand!=='string')brand=null; }catch(e){}
                return {id:(ean||name), name:name, price:price, comparison:comp, image:image, brand:brand, category:cat};
              }).filter(function(x){return x.name;});
              window.__krProducts={query:(j.searchQuery||''), products:out};
            }).catch(function(){});
          }
        }catch(e){}
        return p;
      };
    })();
    """
}

extension KRuokaWebEngine: WKNavigationDelegate {
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

/// A normalized product from the K-ruoka page capture.
struct KRuokaProduct: Decodable {
    let id: String
    let name: String
    let price: Double?
    let comparison: String?
    let image: String?
    let brand: String?
    let category: String?
}

private struct KRuokaCapture: Decodable {
    let query: String
    let products: [KRuokaProduct]
}
