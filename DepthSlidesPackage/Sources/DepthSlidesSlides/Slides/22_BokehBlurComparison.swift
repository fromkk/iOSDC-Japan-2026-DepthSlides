import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct BokehBlurComparison: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    HeaderedSlide(.bokehBlurComparison) {
      SlideWrapper {
        converter.convertPage(
          """
          ## 様々なボケを試して最適なものを選ぶ

          Core Image のブラーは 7 種類。役割で分けると 4 グループ

          - 一様にぼかす: **CIBoxBlur** / **CIDiscBlur** / **CIGaussianBlur**
          - 場所ごとに強さを変える: **CIMaskedVariableBlur**
          - レンズ風: **CIBokehBlur**
          - 演出寄り: CIZoomBlur / CIMotionBlur
          """
        )
      }
    }
  }

  var script: String = """
    Core Image には 7 種類のブラーフィルターがありますが、役割で分けると 4 グループになります。
    1 つ目は画像全体を一様にぼかすもの。Box、Disc、Gaussian で、ぼかす範囲の形が違うだけです。これらは深度マップをマスクにして、ボケた画像と元画像を合成して使います。
    2 つ目は CIMaskedVariableBlur で、グレースケールのマスクで場所ごとにボケの強さを変えられます。深度マップをそのままマスクにできるのがポイントです。
    3 つ目は CIBokehBlur で、円形のボケにリング状の強調と柔らかさを加えられる、レンズのボケ味に一番近いフィルターです。
    Zoom と Motion はブレの表現なので今回の目的には合いません。
    これもどう違うのか、シミュレーターで比較してみます。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehBlurComparison()
  }
}
