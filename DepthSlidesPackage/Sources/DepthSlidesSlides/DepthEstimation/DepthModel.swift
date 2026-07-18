import Foundation

/// アプリに同梱・利用できる Core ML 深度推定モデル。
/// 対応する `.mlpackage` は `scripts/` 配下のスクリプトで
/// `DepthSlidesPackage/Sources/DepthSlidesSlides/Models/` に配置する
/// （リポジトリにはコミットされていないため、ビルド前にスクリプトの実行が必要）。
enum DepthModel: String, CaseIterable, Identifiable, Hashable {
  case depthAnythingV2Small
  case depthAnythingV3Small
  case depthPro
  case midasSmall

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .depthAnythingV2Small: "Depth Anything V2 Small (F16)"
    case .depthAnythingV3Small: "Depth Anything V3 (da3-small)"
    case .depthPro: "Depth Pro"
    case .midasSmall: "MiDaS Small"
    }
  }

  /// `Models/` に配置される .mlpackage のファイル名（拡張子除く）。
  var resourceName: String {
    switch self {
    case .depthAnythingV2Small: "DepthAnythingV2SmallF16"
    case .depthAnythingV3Small: "DepthAnythingV3Small"
    case .depthPro: "DepthPro"
    case .midasSmall: "MiDaSSmall"
    }
  }

  /// Depth Pro は約1.8GBあり iOS の実行時メモリ上限に抵触するため、macOS でのみ有効にする。
  /// (17_ModelUsageNotes.swift / note.md 参照)
  var isAvailableOnCurrentPlatform: Bool {
    switch self {
    case .depthPro:
      #if os(macOS)
        true
      #else
        false
      #endif
    default:
      true
    }
  }

  /// 現在のプラットフォームで利用可能なモデルのみを列挙する。
  static var availableCases: [DepthModel] {
    allCases.filter(\.isAvailableOnCurrentPlatform)
  }

  /// `Bundle.module` 内に配置された .mlpackage の URL。スクリプト未実行などで
  /// モデルが存在しない場合は nil。
  var packageURL: URL? {
    Bundle.module.url(forResource: resourceName, withExtension: "mlpackage", subdirectory: "Models")
  }
}
