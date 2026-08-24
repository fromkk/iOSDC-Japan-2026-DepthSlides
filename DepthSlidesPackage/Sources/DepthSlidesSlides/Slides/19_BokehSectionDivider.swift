import MarkdownToSlide
import SlideKit
import SwiftUI

/// 「ボカす」セクションの扉。パイプライン図の現在地を強調する。
@Slide
struct BokehSectionDivider: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack(alignment: .leading, spacing: 48) {
      Text("ボカす")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)
      PipelineDiagramView(highlighted: .blur)
      Text("深度をマスクにして、Core Image のブラーフィルターで背景だけをボカす")
        .font(theme.headingH3Font)
        .foregroundStyle(theme.secondaryTextColor)
        .frame(maxWidth: .infinity)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    深度が手に入ったので、次はボカし方です。深度をマスクにして、Core Image のブラーフィルターで背景だけをボカします。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehSectionDivider()
  }
}
