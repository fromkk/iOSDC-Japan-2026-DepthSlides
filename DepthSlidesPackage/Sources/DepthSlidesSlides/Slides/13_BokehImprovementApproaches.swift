import MarkdownToSlide
import SlideKit
import SwiftUI

/// 本題の全体像: 写真 → 深度を得る → ボカす → 結果 のパイプライン。
@Slide
struct BokehImprovementApproaches: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack(alignment: .leading, spacing: 48) {
      Text("スマホで撮影した写真をミラーレス級に近づけるためのアプローチ")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)
      PipelineDiagramView()
      Text("ポートレートモードと同じことを、自分でやる")
        .font(theme.headingH2Font)
        .foregroundStyle(theme.accentColor)
        .frame(maxWidth: .infinity)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    ここからが本題です。やることはポートレートモードと同じで、写真から深度を手に入れて、その深度をもとに背景をボカす、この 2 ステップです。
    深度は、写真に埋め込まれた AVDepthData を使う方法と、配布されている ML モデルで推定する方法を試しました。ボカす方は Core Image のブラーフィルターを一通り比較しました。
    この順番で見ていきます。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehImprovementApproaches()
  }
}
