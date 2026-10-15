// Shows the DO IT website, lets the video play with sound, and catches
// doit://break?minutes=N when the steps are finished.
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    let onBreak: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onBreak: onBreak) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onBreak: (Int) -> Void
        init(onBreak: @escaping (Int) -> Void) { self.onBreak = onBreak }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.allow) }
            if url.scheme == "doit" {
                let minutes = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "minutes" })?.value.flatMap(Int.init) ?? Break.minMinutes
                onBreak(minutes)
                return decisionHandler(.cancel)
            }
            // Links that leave DO IT (like YouTube) open in Safari.
            if action.navigationType == .linkActivated, url.host != siteURL.host {
                UIApplication.shared.open(url)
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }

        // Links with target="_blank".
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { UIApplication.shared.open(url) }
            return nil
        }
    }
}
