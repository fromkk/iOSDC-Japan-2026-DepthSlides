import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct ConvexLensSimulation: View {
  @Environment(\.slideTheme) var slideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("凸レンズのシミュレーション")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      Text("レンズは光を一点に集める。集まる位置とスクリーンがずれると像がにじんでボケになる")
        .font(slideTheme.headingH3Font)
        .foregroundStyle(slideTheme.accentColor)

      ConvexLensSlideView()
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String = """
    凸レンズのシミュレーションがこちらです。
    レンズの左側が投影する物体、右側がスクリーン（カメラではセンサー）です。
    このオレンジの線が焦点距離です。
    針の穴とは違ってレンズを通すと広い光を一箇所に集めることができるので焦点を作ることができます。
    先ほど虫眼鏡と言いましたが、虫眼鏡で太陽の光を集めて紙を燃やす実験をしたことがある方もいると思います。まさにその光が集まる点が焦点です。
    （物体〜レンズの距離を動かして）このようにレンズと物体の距離を変更すると焦点距離が変わってしまい物体がはっきりと映らなくなることが分かります。
    これがボケの正体です。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    ConvexLensSimulation()
  }
}
