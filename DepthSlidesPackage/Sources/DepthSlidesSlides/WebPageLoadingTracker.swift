import SwiftUI

/// PDF エクスポート時に各レンダリングコンテキストの WebView ロード状態を追跡するクラス
@MainActor
public final class WebPageLoadingTracker {
  private var pendingCount: Int = 0

  public init() {}

  /// WebView がロードを開始したことを通知する
  public func startedLoading() {
    pendingCount += 1
  }

  /// WebView がロードを完了したことを通知する
  public func finishedLoading() {
    pendingCount = max(0, pendingCount - 1)
  }

  /// 全ての WebView のロードが完了しているか（未登録の場合も true）
  public var isAllLoaded: Bool {
    pendingCount <= 0
  }
}

private struct WebPageLoadingTrackerKey: EnvironmentKey {
  nonisolated static let defaultValue: WebPageLoadingTracker? = nil
}

public extension EnvironmentValues {
  var webPageLoadingTracker: WebPageLoadingTracker? {
    get { self[WebPageLoadingTrackerKey.self] }
    set { self[WebPageLoadingTrackerKey.self] = newValue }
  }
}
