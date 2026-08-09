import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PinholeCameraSimulation: View {
  @Environment(\.slideTheme) var slideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("カメラ・オブスキュラの概要")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      PinholeCameraSlideView()
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String = """
    カメラ・オブスキュラは針の穴ほどの小さな点である必要があります。
    光は直進する性質を持つので小さな穴を通るとそのまま壁に当たります。
    上から入った光は下に、下から入った光は上に当たります。
    そのため上下・左右逆さまに投影されるということです。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    PinholeCameraSimulation()
  }
}
