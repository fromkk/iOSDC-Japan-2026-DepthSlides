import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct Summary: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # まとめ

        - 「精度」と「動作環境の制約」はトレードオフ
        - 1つのモデルだけでは実用に足りない
        - 現時点ではDepth Anything V3の採用が最適
        - ボケ描画方式も含めた使い分けの知見を共有
        """
      )
    }
  }

  var script: String = """
    まとめです。
    「精度」と「動作環境の制約」はトレードオフであり、1つのモデルだけでは実用に足りません。
    現時点ではDepth Anything V3を採用するのが最適という結論になりました。
    複数モデル比較アプリの実装で得た知見と、ボケ描画方式も含めた使い分け設計を共有しました。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    Summary()
  }
}
