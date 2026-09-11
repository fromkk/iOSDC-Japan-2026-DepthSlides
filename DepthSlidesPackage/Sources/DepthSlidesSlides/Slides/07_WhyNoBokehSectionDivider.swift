import MarkdownToSlide
import SlideKit
import SwiftUI

/// 第1幕「なぜ iPhone はボケないか」の扉。
///
/// 第2幕以降の扉は `PipelineDiagramView` で現在地を示すが、この時点では
/// まだパイプラインの話をしていないので、章題だけのシンプルな扉にしている。
@Slide
struct WhyNoBokehSectionDivider: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack(alignment: .leading, spacing: 40) {
      SlideHeader(.cameraObscuraOrigin)
      Text("なぜスマホで撮った写真はボケないのか")
        .font(theme.headingH1Font)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(theme.contentPadding)
  }

  var script: String = """
    最初に、なぜスマホで撮った写真はボケないのか、について説明するために、
    カメラの起源・仕組みを振り返ります。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    WhyNoBokehSectionDivider()
  }
}
