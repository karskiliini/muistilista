import SwiftUI
import WebKit

/// Shows Motonet's own store picker (which has a "use my location" button) in
/// a real web view. When the user is done, we read the chosen store's name and
/// let the persistent cookie carry the selection into the shelf lookups.
struct MotonetStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator = WebCoordinator()

    var body: some View {
        NavigationStack {
            MotonetStoreWebView(coordinator: coordinator)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Valitse Motonet-tavaratalo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Valmis") {
                            coordinator.readSelectedStore { name in
                                if let name { MotonetWebEngine.shared.didSelectStore(named: name) }
                                dismiss()
                            }
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Peruuta") { dismiss() }
                    }
                }
        }
    }

    @MainActor
    final class WebCoordinator {
        weak var webView: WKWebView?

        /// Best-effort read of the currently selected store's name from the
        /// header; nil if none looks selected.
        func readSelectedStore(_ completion: @escaping (String?) -> Void) {
            let js = """
            (function(){
              var t = document.body ? document.body.innerText : '';
              var m = t.match(/Oma Motonet\\s*\\n?([^\\n]{3,40})/i);
              if (m && m[1] && !/valitse/i.test(m[1])) return m[1].trim();
              return '';
            })()
            """
            webView?.evaluateJavaScript(js) { result, _ in
                let name = (result as? String) ?? ""
                completion(name.isEmpty ? "Motonet-tavaratalo" : name)
            }
        }
    }
}

private struct MotonetStoreWebView: UIViewRepresentable {
    let coordinator: MotonetStoreSheet.WebCoordinator

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // shares cookies with the shelf engine
        let web = WKWebView(frame: .zero, configuration: config)
        web.load(URLRequest(url: MotonetWebEngine.storeSelectorURL))
        coordinator.webView = web
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
