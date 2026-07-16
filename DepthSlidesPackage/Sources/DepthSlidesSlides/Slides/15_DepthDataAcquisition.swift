import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct DepthDataAcquisition: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      // TODO: AVDepthData を取得するコードと深度画像（Depth Image）を載せる
      converter.convertPage(
        """
        # 写真に含まれる深度情報を取得

        ```swift
        // TODO: AVDepthData を取得するコード
        ```

        （Depth Image）
        """
      )
    }
  }

  var script: String = """
    まずは写真に含まれる深度情報を取得してみます。コードはこのようになります。
    取得した深度は、このような画像として可視化できます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    DepthDataAcquisition()
  }
}
