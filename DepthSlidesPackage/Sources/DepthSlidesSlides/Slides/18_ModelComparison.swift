import MarkdownToSlide
import SlideKit
import SwiftUI

/// 配布モデル 4 つの紹介 → スペック表 → 深度の種類 → ライセンス。
/// 表の注目セル（1.8GB・絶対深度など）は太字にして、強調は口頭で行う。
@Slide
struct ModelComparison: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case spec
    case depthType
    case license
  }

  @Phase var phase: SlidePhase

  let converter = MarkdownToSlideConverter()

  var body: some View {
    HeaderedSlide(.modelComparison) {
      SlideWrapper {
        converter.convertPage(markdown)
      }
    }
  }

  private var markdown: String {
    switch phase {
    case .initial:
      return """
        ## 配布されている ML モデルを利用して深度を推定する

        \(DepthModel.mlModelCases.map { "- \($0.displayName)" }.joined(separator: "\n"))
        """
    case .spec:
      return """
        ## スペック比較

        \(specTable)

        ※ 単眼深度推論に使う部分のみを Core ML 変換したもの（61MB / FP16）
        """
    case .depthType:
      return """
        ## 深度の種類

        | | MiDaS Small | DA V2 Small | Depth Pro | DA3 Small |
        |---|---|---|---|---|
        | 深度の種類 | 相対深度 | 相対深度 | **絶対深度（メートル）** | 相対深度 |

        - 相対深度: どこが手前でどこが奥かが分かる
        - 絶対深度: メートル単位の実距離が分かる
          - Depth Pro は焦点距離の推定も可能
          - 本物のレンズの被写界深度計算を再現したい場合に有効
        """
    case .license:
      return """
        ## ライセンス

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
        注目してほしいのはモデルサイズで、Depth Pro だけ 1.8GB と桁が2つ違います。他の3つは 32〜61MB に収まっているので、アプリに同梱することを考えると、この差はかなり効いてきます。
        """
    case .depthType:
      return """
        出力される深度にも種類があります。MiDaS と Depth Anything は相対深度、つまりどこが手前でどこが奥か、という相対的な関係だけが分かります。ボケを作るだけならこれで十分です。
        一方 Depth Pro は絶対深度、メートル単位の実距離を返してくれて、さらに焦点距離の推定もできます。本物のレンズの被写界深度計算を再現したい場合はこちらが有効です。
        """
    case .license:
      return """
        そして見落としがちなのがライセンスです。Depth Anything V2 で Apache-2.0 なのは実は Small だけで、Base 以上は商用不可の CC-BY-NC です。Depth Pro も Apple の研究用ライセンスなので、商用アプリへの組み込みは不可と考えるのが安全です。
        精度が良いモデルがそのままアプリに使えるとは限らない、というのは注意が必要なポイントです。
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

#Preview("license") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<ModelComparison.SlidePhase>(.license)
  }
  let controller = SlideIndexController(container: container) {
    ModelComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}
