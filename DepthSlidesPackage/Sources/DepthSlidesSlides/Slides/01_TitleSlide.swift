import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct TitleSlide: View {
  @Environment(\.slideTheme) var theme

  var shouldHideIndex: Bool { true }

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 120) {
        Text("複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける")
          .font(theme.headingH1Font)
          .oldLensLight(.title)

        Text("iOSDC Japan 2026 @fromkk")
          .font(theme.headingH2Font)
          .foregroundStyle(theme.secondaryTextColor)
          .oldLensLight(.subtle)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { OldLensLightLeakBackground() }
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
