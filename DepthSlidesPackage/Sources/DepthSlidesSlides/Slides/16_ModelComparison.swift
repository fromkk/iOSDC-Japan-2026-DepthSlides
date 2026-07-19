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
        # 配布されている ML モデルを利用して深度を推定する

        - Depth Anything V2
        - Depth Anything V3
        - Depth Pro
        """
      )
    }
  }

  var script: String = """
    次に、配布されている ML モデルを使った深度推定です。今回は Depth Anything V2、Depth Anything V3、Depth Pro の3つを試しました。
    どう違うのか、シミュレーターを作って比較してみます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    ModelComparison()
  }
}
