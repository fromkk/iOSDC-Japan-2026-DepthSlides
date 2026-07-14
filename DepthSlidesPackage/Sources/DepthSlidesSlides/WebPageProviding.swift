import WebKit

/// PDF エクスポート時に WebPage のロード完了を待機するためのプロトコル
@MainActor
public protocol WebPageProviding {
  var webPages: [WebPage] { get }
}
