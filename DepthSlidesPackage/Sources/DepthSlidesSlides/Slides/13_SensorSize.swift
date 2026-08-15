import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct SensorSize: View {
  @Environment(\.slideTheme) var slideTheme
  let converter = MarkdownToSlideConverter()

  var body: some View {
    HStack {
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

      VStack(alignment: .leading) {
        Image(.sensorSizesOverlaidInside)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 600)

        Text("https://en.wikipedia.org/wiki/File:Sensor_sizes_overlaid_inside.svg")
          .font(slideTheme.bodyFont)
          .frame(width: 600)
          .multilineTextAlignment(.leading)
      }
      .padding(slideTheme.contentPadding)
    }
  }

  var script: String = """
    次にセンサーサイズです。デジタルカメラには 1型、マイクロフォーサーズ、APS-C、フルサイズ、中判など、様々なセンサーサイズがあります。
    センサーが大きいほど画素をたくさん並べられるので高画素で記録できますし、たくさんの光を受け取ることができます。
    そしてセンサーが大きいほど被写界深度が浅くなる、つまりボケやすくなります。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    SensorSize()
  }
}
