import SwiftUI
import WebKit

/// WKWebView を直接ラップした SwiftUI View。
/// iOS 26 の WebView(webPage:) を使わないため複数ウィンドウでも安全。
/// Environment の webPageLoadingTracker に対してロード状態を通知する。
public struct WebContentView: View {
  let url: URL
  @Environment(\.webPageLoadingTracker) private var tracker

  public init(url: URL) {
    self.url = url
  }

  public var body: some View {
    _WebViewRepresentable(url: url, tracker: tracker)
  }
}

// MARK: - UIKit

#if canImport(UIKit)
  private struct _WebViewRepresentable: UIViewRepresentable {
    let url: URL
    let tracker: WebPageLoadingTracker?

    func makeCoordinator() -> Coordinator {
      Coordinator(tracker: tracker)
    }

    func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.navigationDelegate = context.coordinator
      webView.isOpaque = false
      webView.backgroundColor = .clear
      Task { @MainActor in
        tracker?.startedLoading()
      }
      webView.load(URLRequest(url: url))
      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
  }
#endif

// MARK: - AppKit

#if os(macOS)
  private struct _WebViewRepresentable: NSViewRepresentable {
    let url: URL
    let tracker: WebPageLoadingTracker?

    func makeCoordinator() -> Coordinator {
      Coordinator(tracker: tracker)
    }

    func makeNSView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.navigationDelegate = context.coordinator
      webView.setValue(false, forKey: "drawsBackground")
      Task { @MainActor in
        tracker?.startedLoading()
      }
      webView.load(URLRequest(url: url))
      return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
  }
#endif

// MARK: - Coordinator（共通）

#if canImport(UIKit) || os(macOS)
  extension _WebViewRepresentable {
    final class Coordinator: NSObject, WKNavigationDelegate {
      let tracker: WebPageLoadingTracker?

      init(tracker: WebPageLoadingTracker?) {
        self.tracker = tracker
      }

      func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
          tracker?.finishedLoading()
        }
      }

      func webView(
        _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
      ) {
        Task { @MainActor in
          tracker?.finishedLoading()
        }
      }

      func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
      ) {
        Task { @MainActor in
          tracker?.finishedLoading()
        }
      }
    }
  }
#endif
