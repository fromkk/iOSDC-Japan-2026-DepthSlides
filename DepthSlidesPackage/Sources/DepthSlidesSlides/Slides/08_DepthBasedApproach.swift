import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct DepthBasedApproach: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # 提案アプローチ：撮影後の深度ベースのボケ再現

        - 撮影済みの写真から深度を取得する
        - 深度をもとに、後からボケを再現する
        - CoreMLを使った画像からの深度推定モデルを利用する
        - 撮影時にセンサーを使わずとも、後から深度を推定できる
        """
      )
    }
  }

  var script: String = """
    そこで必要になるのが、撮影済みの写真から深度を取得し、後からボケを再現するアプローチです。
    iPhoneではCoreMLを使った画像からの深度推定モデルが利用でき、撮影時に特別なセンサーがなくても、後から深度を推定できます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    DepthBasedApproach()
  }
}
