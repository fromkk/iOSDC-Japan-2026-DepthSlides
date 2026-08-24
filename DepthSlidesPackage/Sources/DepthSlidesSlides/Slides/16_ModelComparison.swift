import MarkdownToSlide
import SlideKit
import SwiftUI

/// 配布モデル 4 つの紹介 → スペック表 → 「1.8GB」ドン → 深度の種類 → ライセンス → 「Small だけ」ドン
/// 数字を見せるフェーズは表を消して数字 1 つだけを大きく出す（メリハリ）。
@Slide
struct ModelComparison: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case spec
    case size
    case depthType
    case license
    case licenseTakeaway
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme

  let converter = MarkdownToSlideConverter()

  var body: some View {
    switch phase {
    case .size:
      bigNumber(
        headline: "1.8GB",
        sub: "Depth Pro だけ桁違い。他の 3 つは 32〜61MB",
        note: "アプリに同梱できるかどうかが決まる")
    case .licenseTakeaway:
      bigNumber(
        headline: "商用 OK は Small だけ",
        sub: "Depth Anything V2 の Base 以上は CC-BY-NC、Depth Pro は研究用ライセンス",
        note: "精度が良い = アプリに使える、ではない")
    default:
      SlideWrapper {
        converter.convertPage(markdown)
      }
    }
  }

  private func bigNumber(headline: String, sub: String, note: String) -> some View {
    VStack(spacing: 40) {
      Spacer()
      Text(headline)
        .font(.system(size: 200, weight: .heavy))
        .foregroundStyle(theme.accentColor)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
      Text(sub)
        .font(theme.headingH2Font)
        .foregroundStyle(theme.primaryTextColor)
        .multilineTextAlignment(.center)
      Text(note)
        .font(theme.headingH3Font)
        .foregroundStyle(theme.secondaryTextColor)
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(theme.contentPadding)
  }

  private var markdown: String {
    switch phase {
    case .initial:
      return """
        # 配布されている ML モデルを利用して深度を推定する

        \(DepthModel.mlModelCases.map { "- \($0.displayName)" }.joined(separator: "\n"))
        """
    case .spec, .size:
      return """
        # スペック比較

        \(specTable)

        ※ 単眼深度推論に使う部分のみを Core ML 変換したもの（61MB / FP16）
        """
    case .depthType:
      return """
        # 深度の種類

        | | MiDaS Small | DA V2 Small | Depth Pro | DA3 Small |
        |---|---|---|---|---|
        | 深度の種類 | 相対深度 | 相対深度 | **絶対深度（メートル）** | 相対深度 |

        - 相対深度: どこが手前でどこが奥かが分かる（ボケ生成にはこれで十分）
        - 絶対深度: メートル単位の実距離が分かる
          - Depth Pro は焦点距離の推定も可能
          - 本物のレンズの被写界深度計算を再現したい場合に有効
        """
    case .license, .licenseTakeaway:
      return """
        # ライセンス

        | | MiDaS Small | DA V2 Small | Depth Pro | DA3 Small |
        |---|---|---|---|---|
        | ライセンス | MIT | Apache-2.0 ※ | apple-amlr | Apache-2.0 |

        - ※ Apache-2.0 なのは Small のみ（Base / Large / Giant は CC-BY-NC-4.0 で商用不可）
        - apple-amlr は研究用途向けライセンス（商用アプリへの組み込みは不可と考えるのが安全）
        """
    }
  }

  private var specTable: String = """
    | | MiDaS Small | DA V2 Small | Depth Pro | DA3 Small |
    |---|---|---|---|---|
    | 公開 | 2020年 | 2024年6月 | 2024年10月 | 2025年11月 |
    | 開発元 | Intel ISL | HKU / TikTok | Apple | ByteDance |
    | バックボーン | CNN | ViT-S | ViT-L ×2 | ViT-S 相当 |
    | パラメータ数 | 約21M | 24.8M | 約504M | 公称 0.08B ※ |
    | モデルサイズ | 32MB | 48MB | **1.8GB** | 61MB |
    | 入力解像度 | 256×256 | 518×392 | 1536×1536 | 504×378 |
    | 深度の種類 | 相対深度 | 相対深度 | **絶対深度（メートル）** | 相対深度 |
    | ライセンス | MIT | Apache-2.0 ※ | apple-amlr | Apache-2.0 |
    """

  var script: String {
    switch phase {
    case .initial:
      return """
        次に、配布されている ML モデルを使った深度推定です。今回は \(DepthModel.mlModelCases.map { $0.displayName }.joined(separator: ", ")) の\(DepthModel.mlModelCases.count)つを試しました。
        """
    case .spec:
      return """
        まずスペックを比較してみます。リリースの古い順に並べると、そのまま深度推定の進化の歴史になっています。2020年の CNN ベースの MiDaS から、ViT ベースになった Depth Anything V2、高解像・高精度に振った Apple の Depth Pro、そして複数視点にも対応した3D基盤モデルの Depth Anything V3 という流れです。
        """
    case .size:
      return """
        ここが今日のポイントの1つ目です。モデルサイズを見てください。Depth Pro だけ 1.8GB と桁が違います。他の3つは 32〜61MB に収まっているので、アプリに同梱することを考えると、この差はかなり効いてきます。
        """
    case .depthType:
      return """
        出力される深度にも種類があります。MiDaS と Depth Anything は相対深度、つまりどこが手前でどこが奥か、という相対的な関係だけが分かります。ボケを作るだけならこれで十分です。
        一方 Depth Pro は絶対深度、メートル単位の実距離を返してくれて、さらに焦点距離の推定もできます。本物のレンズの被写界深度計算を再現したい場合はこちらが有効です。
        """
    case .license:
      return """
        そして見落としがちなのがライセンスです。Depth Anything V2 で Apache-2.0 なのは実は Small だけで、Base 以上は商用不可の CC-BY-NC です。Depth Pro も Apple の研究用ライセンスなので、商用アプリへの組み込みは不可と考えるのが安全です。
        """
    case .licenseTakeaway:
      return """
        つまり、商用アプリで気軽に使えるのは Small サイズのモデルだけ、ということになります。精度が良いモデルがそのままアプリに使えるとは限らない、というのは注意が必要なポイントです。
        では実際にどう違うのか、シミュレーターを作って比較してみます。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview("spec") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<ModelComparison.SlidePhase>(.spec)
  }
  let controller = SlideIndexController(container: container) {
    ModelComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("size") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<ModelComparison.SlidePhase>(.size)
  }
  let controller = SlideIndexController(container: container) {
    ModelComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("licenseTakeaway") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<ModelComparison.SlidePhase>(.licenseTakeaway)
  }
  let controller = SlideIndexController(container: container) {
    ModelComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}
