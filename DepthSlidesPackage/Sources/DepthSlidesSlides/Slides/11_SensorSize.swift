import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct SensorSize: View {
  @Environment(\.slideTheme) var slideTheme
  let converter = MarkdownToSlideConverter()

  var body: some View {
    HStack(alignment: .top, spacing: 32) {
      SlideWrapper {
        converter.convertPage(
          """
          # センサーサイズ

          - センサーが大きいほど
            - たくさんの光を受け取れる
            - **被写界深度が浅くなる（ボケやすい）**
          - iPhone 17 Pro の最大センサーは 1/1.28型
            - 面積はフルサイズの約 **1/\(SensorSizeDiagramView.fullFrameToiPhoneAreaRatio)**
          """
        )
      }

      VStack(alignment: .leading, spacing: 8) {
        SensorSizeDiagramView()
        Text("実寸比（mm）")
          .font(slideTheme.bodyFont)
          .foregroundStyle(slideTheme.secondaryTextColor)
      }
      .frame(width: 880)
      .padding(.trailing, slideTheme.contentPadding)
      .padding(.vertical, slideTheme.contentPadding)
    }
  }

  var script: String = """
    次にセンサーサイズです。センサーが大きいほどたくさんの光を受け取れて、そして被写界深度が浅くなる、つまりボケやすくなります。
    右の図は実寸比です。一番外側が中判、その次がフルサイズ。オレンジが iPhone 17 Pro の一番大きなセンサーで、面積にするとフルサイズの約 \(SensorSizeDiagramView.fullFrameToiPhoneAreaRatio) 分の 1 しかありません。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    SensorSize()
  }
}
