import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct BokehImprovementApproaches: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # ボケの違和感を改善するアプローチ

        - 写真に含まれる深度情報（AVDepthData）を取得してボケさせてみる（Portrait Mode のアプローチ）
        - 配布されている ML モデルを利用して深度を推定する
        - 様々なボケを試して最適なものを選ぶ
        """
      )
    }
  }

  var script: String = """
    ここからが本題です。このボケの違和感を改善するために、3つのアプローチを試しました。
    1つ目は、写真に含まれる深度情報、AVDepthData を取得してボケさせてみる、Portrait mode と同じアプローチです。
    2つ目は、配布されている ML モデルを利用して深度を推定するアプローチです。
    3つ目は、様々なボケを試して最適なものを選ぶ、というものです。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehImprovementApproaches()
  }
}
