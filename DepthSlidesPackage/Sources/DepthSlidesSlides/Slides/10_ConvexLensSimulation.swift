import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct ConvexLensSimulation: View {
  @Environment(\.slideTheme) var slideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("レンズのシミュレーション")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      ConvexLensSlideView()
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String = """
    レンズを通した場合のシミュレーションがこちらです。
    このオレンジの線が焦点距離です。
    針の穴とは違ってレンズを通すと広い光を一箇所に集めることができるので焦点を作ることができます。
    先ほど虫眼鏡と言いましたが、虫眼鏡で太陽の光を当てて紙を燃やす実験をしたことがあるかもしれませんが、まさにその光が集まる点が焦点です。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    ConvexLensSimulation()
  }
}
