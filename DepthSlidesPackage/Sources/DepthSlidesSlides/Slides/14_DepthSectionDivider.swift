import MarkdownToSlide
import SlideKit
import SwiftUI

/// 「深度を得る」セクションの扉。パイプライン図の現在地を強調する。
@Slide
struct DepthSectionDivider: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack(alignment: .leading, spacing: 48) {
      Text("深度を得る")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)
      PipelineDiagramView(highlighted: .depth)
      Text("写真に埋め込まれた深度 → 無ければ ML モデルで推定する")
        .font(theme.headingH3Font)
        .foregroundStyle(theme.secondaryTextColor)
        .frame(maxWidth: .infinity)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    まずは深度をどう手に入れるかです。写真にすでに深度が埋め込まれていればそれを使い、無ければ ML モデルで推定します。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    DepthSectionDivider()
  }
}
