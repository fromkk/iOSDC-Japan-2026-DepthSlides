import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct BokehBlurComparison: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # 様々なボケを試して最適なものを選ぶ

        Core Image のブラーは 7 種類。役割で分けると 4 グループ

        - 一様にぼかす: **CIBoxBlur** / **CIDiscBlur** / **CIGaussianBlur**
          - 範囲の形（正方形・円・ガウス分布）が違うだけ。深度マスクで合成して使う
        - 場所ごとに強さを変える: **CIMaskedVariableBlur**
          - 深度マップをそのままマスクにできる
        - レンズ風: **CIBokehBlur**
          - 円形のボケにリング状の強調（ringSize / ringAmount）と softness
        - 演出寄り: CIZoomBlur / CIMotionBlur
          - ブレの表現なので今回の目的には合わない
        """
      )
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
