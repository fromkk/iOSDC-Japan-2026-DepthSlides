import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct TitleSlide: View {
  var shouldHideIndex: Bool { true }

  var body: some View {
    SlideWrapper {
      let converter = MarkdownToSlideConverter()
      converter.convertPage(
        """
        # 複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける
        """
      )
    }
  }

  var script: String = """
    複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける、というタイトルでお話しします。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    TitleSlide()
  }
}
