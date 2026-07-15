import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct HowCameraWorks: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # そもそものカメラの仕組み

        - レンズ：光を集めて像を結ぶ
        - 絞り（アパーチャ）：レンズを通る光の量を調整する穴
        - センサー：像を電気信号に変換して記録する
        """
      )
    }
  }

  var script: String = """
    カメラの基本的な仕組みをおさらいします。
    レンズが光を集めて像を結び、絞りが光の量を調整し、センサーがその像を記録します。
    この後の「ボケ」の話は、主にレンズと絞り、センサーの関係から生まれます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    HowCameraWorks()
  }
}
