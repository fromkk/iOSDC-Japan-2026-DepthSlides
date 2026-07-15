import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PortraitModeLimits: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # Portraitモードの限界

        - LiDARなどのセンサー情報を活用して深度を取得し、ボケを生成している
        - 撮影前にモードを切り替える必要がある
        - F値の調整に手間がかかる
        - 生成されるボケの見え方にも違和感が残る
        """
      )
    }
  }

  var script: String = """
    iPhoneにはPortraitモードがあり、LiDARなどのセンサー情報を活用して深度を取得し、ボケを生成しています。
    ただ、撮影前にモードを切り替えたりF値を調整したりする手間があり、ボケの見え方にも違和感が残る課題があります。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    PortraitModeLimits()
  }
}
