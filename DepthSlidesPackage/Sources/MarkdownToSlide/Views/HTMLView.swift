import SwiftUI
import WebKit

// MARK: - HTMLView

struct HTMLView: View {
  @Environment(\.slideTheme) private var theme
  let htmlContent: String
  @State private var contentHeight: CGFloat = 0

  var body: some View {
    HTMLWebView(
      htmlContent: htmlContent,
      theme: theme,
      contentHeight: $contentHeight
    )
    .frame(maxWidth: .infinity)
    .frame(height: contentHeight > 0 ? contentHeight : nil)
  }
}

#if canImport(UIKit)
  private struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    let theme: SlideTheme
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.navigationDelegate = context.coordinator
      webView.scrollView.isScrollEnabled = false
      webView.isOpaque = false
      webView.backgroundColor = .clear
      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
      loadHTML(into: webView)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(contentHeight: $contentHeight)
    }
  }
#else
  private struct HTMLWebView: NSViewRepresentable {
    let htmlContent: String
    let theme: SlideTheme
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.navigationDelegate = context.coordinator
      webView.setValue(false, forKey: "drawsBackground")
      return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
      loadHTML(into: webView)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(contentHeight: $contentHeight)
    }
  }
#endif

extension HTMLWebView {
  func loadHTML(into webView: WKWebView) {
    let cssStyle = theme.generateHTMLCSS()

    let html = """
      <!DOCTYPE html>
      <html>
      <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
              \(cssStyle)
          </style>
      </head>
      <body>
          \(htmlContent)
      </body>
      </html>
      """
    webView.loadHTMLString(html, baseURL: nil)
  }

  class Coordinator: NSObject, WKNavigationDelegate {
    @Binding var contentHeight: CGFloat

    init(contentHeight: Binding<CGFloat>) {
      _contentHeight = contentHeight
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      webView.evaluateJavaScript("document.body.scrollHeight") {
        result,
        error in
        if let height = result as? CGFloat {
          DispatchQueue.main.async {
            self.contentHeight = height
          }
        }
      }
    }
  }
}
