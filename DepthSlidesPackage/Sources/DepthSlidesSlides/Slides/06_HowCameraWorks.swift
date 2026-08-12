import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct HowCameraWorks: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    HStack(alignment: .center) {
      Text("カメラの仕組み")
        .font(SlideTheme.default.headingH1Font)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    .padding(SlideTheme.default.contentPadding)
  }

  var script: String = """
    そもそもカメラの仕組みについて振り返ってみようと思います。
    カメラってどうやってできているでしょうか？
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    HowCameraWorks()
  }
}
