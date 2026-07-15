import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct ModelComparison: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # モデルの比較

        CoreMLで動く複数の深度推定モデルを実際にアプリへ組み込み、同じ写真で切り替えてボケの見え方を比較検証しました。

        ## Depth Pro
        - 推定精度は高い
        - 約1.8GBという巨大なモデルサイズ
        - iPhoneの実行時メモリ上限に抵触し、macOS限定でしか動作しない

        ## Depth Anything V2 Small (F16)
        - 軽量で、iOS実機でも安定動作する
        - 深度マップの解像度が低く、輪郭のボケに荒さが目立つ

        ## Depth Anything V3
        - V2同様に軽量
        - V2より精度が高い
        """
      )
    }
  }

  var script: String = """
    本トークでは、CoreMLで動く複数の深度推定モデル、Depth Pro、Depth Anything V2 Small、Depth Anything V3を実際にアプリへ組み込み、同じ写真で切り替えてボケの見え方を比較検証しました。
    Depth Proは推定精度が高いものの、約1.8GBという巨大なモデルサイズがiPhoneの実行時メモリ上限に抵触し、macOS限定でしか動作しませんでした。
    Depth Anything V2 Smallは軽量でiOS実機でも安定動作しますが、深度マップの解像度が低く輪郭のボケに荒さが目立ちます。
    Depth Anything V3はV2同様に軽量でありながら、V2より精度が高いという結果になりました。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    ModelComparison()
  }
}
