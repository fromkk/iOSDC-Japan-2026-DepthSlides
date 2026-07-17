import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct TitleSlide: View {
  var shouldHideIndex: Bool { true }

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 120) {
        Text("複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける")
          .font(SlideTheme.default.headingH1Font)

        Text("iOSDC Japan 2026 @fromkk")
          .font(SlideTheme.default.headingH2Font)
          .foregroundStyle(SlideTheme.default.secondaryTextColor)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .padding(SlideTheme.default.contentPadding)
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
