import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct SensorSize: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # センサーサイズ

        - デジタルカメラには様々なセンサーサイズがある
          - 1型（1インチ）
          - マイクロフォーサーズ（4/3型）
          - APS-C
          - フルサイズ（35mm判）
          - 中判（ミディアムフォーマット）
        - センサーサイズによる違い
          - 大きい方が高画素で記録可能（センサーをたくさん並べることができる）
          - 大きい方がたくさんの光を受け取ることができる
          - 大きい方が被写界深度が浅くなる（ボケやすくなる）
        """
      )
    }
  }

  var script: String = """
    次にセンサーサイズです。デジタルカメラには 1型、マイクロフォーサーズ、APS-C、フルサイズ、中判など、様々なセンサーサイズがあります。
    センサーが大きいほどたくさん並べられるので高画素で記録できますし、たくさんの光を受け取ることができます。
    そして大きいほど被写界深度が浅くなる、つまりボケやすくなります。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    SensorSize()
  }
}
