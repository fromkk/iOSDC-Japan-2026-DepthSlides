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

      ConvexLensSlideView()
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String = """
    次に凸レンズのシミュレーションです。
    レンズを使うことで、ピンホールよりも多くの光を集めながら、焦点距離に応じた位置に鮮明な像を結ぶことができます。
    物体の位置やレンズの焦点距離を変えると、実像・虚像がどのように変化するかを確認できます。
    これがカメラのレンズが担っている役割です。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    ConvexLensSimulation()
  }
}
