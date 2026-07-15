import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PinholeCameraSimulation: View {
  @Environment(\.slideTheme) var slideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("ピンホールカメラのシミュレーション")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      PinholeCameraSlideView()
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String = """
    ここからは実際にシミュレーションを見ながら説明します。まずピンホールカメラです。
    壁にあけた小さな穴を通った光だけがスクリーンに到達し、像を結びます。
    穴を大きくすると光の通り道が広がり、像がボケていきます。
    これが絞りの実直径とボケの関係を最も単純化したモデルです。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    PinholeCameraSimulation()
  }
}
