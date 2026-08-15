import Foundation

/// アプリに同梱・利用できる Core ML 深度推定モデル。
/// 対応する `.mlpackage` は `scripts/` 配下のスクリプトで
/// `DepthSlidesPackage/Sources/DepthSlidesSlides/Models/` に配置する
/// （リポジトリにはコミットされていないため、ビルド前にスクリプトの実行が必要）。
enum DepthModel: String, CaseIterable, Identifiable, Hashable {
  /// Core ML 推論ではなく、写真自体に埋め込まれた AVDepthData（Portrait Mode
  /// などが記録する視差マップ）をそのまま使う。他の4ケースと違い Core ML
  /// モデルを持たないため `resourceName`/`packageURL` は nil になる。
  case embeddedDepth
  /// ML モデルはリリースの古い順に並べる（スライド・シミュレーターの表示順に影響）:
  /// MiDaS (2020) → Depth Anything V2 (2024/6) → Depth Pro (2024/10) → Depth Anything V3 (2025/11)
  case midasSmall
  case depthAnythingV2Small
  case depthPro
  case depthAnythingV3Small

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .embeddedDepth: "写真に含まれる深度情報"
    case .depthAnythingV2Small: "Depth Anything V2 Small (F16)"
    case .depthAnythingV3Small: "Depth Anything V3 (da3-small)"
    case .depthPro: "Depth Pro"
    case .midasSmall: "MiDaS Small"
    }
  }

  /// `Models/` に配置される .mlpackage のファイル名（拡張子除く）。
  /// `embeddedDepth` は Core ML モデルを使わないため nil。
  var resourceName: String? {
    switch self {
    case .embeddedDepth: nil
    case .depthAnythingV2Small: "DepthAnythingV2SmallF16"
    case .depthAnythingV3Small: "DepthAnythingV3Small"
    case .depthPro: "DepthPro"
    case .midasSmall: "MiDaSSmall"
    }
  }

  /// Depth Pro は約1.8GBあり iOS の実行時メモリ上限に抵触するため、macOS でのみ有効にする。
  /// (15_ModelUsageNotes.swift / note.md 参照)
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

  /// Core ML 推論を行う（写真自体に埋め込まれた `embeddedDepth` を除く）モデルの一覧。
  /// 「配布されているモデル」として紹介するスライドなど、配布モデルのみを
  /// 列挙したい場面で使う。
  static var mlModelCases: [DepthModel] {
    allCases.filter { $0 != .embeddedDepth }
  }

  /// `Bundle.module` 内に配置された .mlpackage の URL。スクリプト未実行などで
  /// モデルが存在しない場合や、`embeddedDepth` のように Core ML モデルを
  /// 使わないケースでは nil。
  var packageURL: URL? {
    guard let resourceName else { return nil }
    return Bundle.module.url(
      forResource: resourceName, withExtension: "mlpackage", subdirectory: "Models")
  }
}
