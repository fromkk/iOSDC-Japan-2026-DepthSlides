import CoreGraphics
import MarkdownToSlide
import SwiftUI

/// 同じ写真・同じ深度マップに 7 種類のブラー系フィルター（`BokehFilterKind`）を
/// 適用した結果を、元画像と並べて一覧表示するView。
///
/// 写真は夜景（`DepthSampleAssets.Sample.cityNight`）を使う。窓明かりが無数の
/// 点光源になるため、Box の四角・Disc の円・Gaussian のにじみといった「ボケの形」の
/// 違いがそのまま絵に出る。ポートレート写真だと背景が平坦で、どのフィルターを
/// かけてもほぼ同じ見た目になってしまい比較にならなかった。
/// パラメーターを触りながら見せる `CIFilterBokehCompareView` と違い、
/// 「どのフィルターがどう違うか」を一目で見比べてもらうことに振り切っている。
struct BokehFilterResultGridView: View {
  @Environment(\.slideTheme) var theme
  @Environment(\.webPageLoadingTracker) private var loadingTracker

  /// 強調表示するフィルター（今回採用したもの）。`22_BokehFilterResults` は
  /// まず全7種をフラットに見せ、次のフェーズで採用したものを強調するため、
  /// フェーズに応じて nil ↔︎ 値 が切り替わる。
  var highlighted: BokehFilterKind?

  /// 深度は写真に埋め込まれていないので推定する。まとめの Before/After
  /// (`BokehBeforeAfterRenderer`) と同じモデルを使う。
  nonisolated private static let depthModel: DepthModel = .depthAnythingV3Small

  /// タイル1枚あたりの描画解像度。スライド上では4列に縮小して表示するので、
  /// 元の 2400px のままレンダリングしても見た目は変わらず時間だけかかる。
  nonisolated private static let renderPixelSize = 1000
  /// 比較用にわざと過剰へ振ったパラメーター。実用的な値（radius 20 前後）だと
  /// 4列に縮小したタイルではフィルター間の差がほとんど見えないため、
  /// 各値を「効果が誇張されて見える」ところまで上げている。
  /// - `radius` 45: 点光源のボケが大きくなり、Box の四角と Disc の円が判別できる
  /// - `amount` 60: Zoom の放射状のブレをはっきり出す
  /// - `ringAmount` 1 / `ringSize` 0.35: Bokeh のリング強調を最大付近まで振る
  /// - `softness` 0: ボケの縁を硬くして、カーネルの形そのものを見せる
  nonisolated private static let parameters = BokehFilterParameters(
    radius: 45,
    amount: 60,
    angle: 0,
    ringAmount: 1,
    ringSize: 0.35,
    softness: 0
  )

  /// タイルは深度推定＋7フィルターの描画結果なので、一度作ったら使い回す
  /// （`render()` は初回だけ走る）。強調表示はスライドのフェーズで変わる
  /// 「見せ方」でしかないため、Tile には焼き込まず body 側で毎回判定する。
  /// ここに `isHighlighted` を持たせると、フェーズを進めても再描画されない
  /// 限り強調が切り替わらない。
  struct Tile: Identifiable {
    let id: String
    let title: String
    let caption: String
    let image: CGImage
  }

  @State private var tiles: [Tile] = []
  @State private var errorMessage: String?

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 12),
    count: 4
  )

  var body: some View {
    Group {
      if tiles.isEmpty {
        RoundedRectangle(cornerRadius: 12)
          .fill(theme.tableBackgroundColor)
          .overlay {
            Text(errorMessage ?? "描画中...")
              .font(theme.bodyFont)
              .foregroundStyle(theme.secondaryTextColor)
          }
      } else {
        LazyVGrid(columns: columns, spacing: 12) {
          ForEach(tiles) { tile in
            tileView(tile)
          }
        }
      }
    }
    .task { await render() }
  }

  private func tileView(_ tile: Tile) -> some View {
    // 元画像のタイルの id ("original") はどの BokehFilterKind とも一致しないので、
    // 強調対象になることはない。
    let isHighlighted = tile.id == highlighted?.id

    return VStack(spacing: 4) {
      Image(decorative: tile.image, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
          if isHighlighted {
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(theme.accentColor, lineWidth: 4)
          }
        }

      Text(tile.title)
        .font(.system(size: 22, weight: isHighlighted ? .bold : .regular))
        .foregroundStyle(
          isHighlighted ? theme.accentColor : theme.primaryTextColor
        )

      Text(tile.caption)
        .font(.system(size: 16))
        .foregroundStyle(theme.secondaryTextColor)
    }
  }

  private func render() async {
    guard tiles.isEmpty else { return }
    loadingTracker?.startedLoading()
    defer { loadingTracker?.finishedLoading() }

    guard let data = DepthSampleAssets.data(for: .cityNight) else {
      errorMessage = "DepthSamples/IMG_8253.heic が見つかりません"
      return
    }
    guard
      let original = DepthSampleAssets.cgImage(
        from: data,
        maxPixelSize: Self.renderPixelSize
      )
    else {
      errorMessage = "元画像の読み込みに失敗しました"
      return
    }
    guard Self.depthModel.packageURL != nil else {
      errorMessage =
        "\(Self.depthModel.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }
    let depth: CGImage
    do {
      depth = try await DepthEstimator.shared.estimateCached(
        cgImage: original,
        model: Self.depthModel,
        cacheKey: DepthCacheKey(imageData: data, model: Self.depthModel)
      )
    } catch {
      errorMessage = "深度の推定に失敗: \(error)"
      return
    }

    let rendered = await Task.detached(priority: .userInitiated) {
      var results: [Tile] = [
        Tile(id: "original", title: "元画像", caption: "ボケなし", image: original)
      ]
      for kind in BokehFilterKind.allCases {
        guard
          let image = CIFilterBokehBlur.apply(
            original: original,
            depth: depth,
            filter: kind,
            parameters: Self.parameters
          )
        else { continue }
        results.append(
          Tile(
            id: kind.id,
            title: kind.displayName,
            caption: Self.caption(for: kind),
            image: image
          )
        )
      }
      return results
    }.value

    tiles = rendered
  }

  /// タイル下に添える一言。`21_BokehBlurComparison` の分類と対応させる。
  nonisolated private static func caption(for kind: BokehFilterKind) -> String {
    switch kind {
    case .boxBlur: "一様: 正方形"
    case .discBlur: "一様: 円"
    case .gaussianBlur: "一様: ガウス分布"
    case .maskedVariableBlur: "深度で強さが変わる"
    case .zoomBlur: "演出寄り（目的に合わない）"
    case .motionBlur: "演出寄り（目的に合わない）"
    case .bokehBlur: "レンズ風（リング強調）"
    }
  }
}

#Preview("強調なし（フェーズ1）") {
  BokehFilterResultGridView()
    .padding()
}

#Preview("CIBokehBlur を強調（フェーズ2）") {
  BokehFilterResultGridView(highlighted: .bokehBlur)
    .padding()
}
