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

        - カメラの歴史・仕組みを振り返ってみました
        - 写真に内蔵されている深度情報を取得してみました
        - 配布されているモデルを利用して深度を推定してみました
        - ボケの Filter を比較してみました
        - 今回僕はモデルに **Depth Anything V3 (da3-small)** を選び、フィルターに **CIBokehBlur** を選びました
        """
      )
    }
  }

  var script: String = """
    まとめです。今日はカメラの歴史と仕組みを振り返り、写真に内蔵されている深度情報を取得し、配布されているモデルで深度を推定して、ボケのフィルターを比較してみました。
    その結果、今回僕はモデルに Depth Anything V3 の da3-small を、フィルターに CIBokehBlur を選びました。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    Summary()
  }
}
