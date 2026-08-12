import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct FNumberDemo: View {
  @Environment(\.slideTheme) var slideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("被写界深度")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      DepthOfFieldSlideView()
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String = """
    実際に見てみましょう。黄色い光線とオレンジの点が、ピントを合わせた被写体です。
    緑の帯が被写界深度、つまりこの範囲にある被写体ならシャープに写る、という距離の範囲を表しています。
    f値を小さくして絞りを開けると、この緑の帯が狭くなり被写界深度が浅くなります。
    逆にf値を大きくして絞りを閉じると、帯が広がって被写界深度が深くなり、遠くまでピントが合うようになります。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    FNumberDemo()
  }
}
