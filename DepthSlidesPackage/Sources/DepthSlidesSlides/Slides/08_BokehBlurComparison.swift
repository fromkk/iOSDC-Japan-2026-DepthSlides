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
        # ボケ生成：CIFilterのBlur系比較

        深度マップが得られたあと、それをどう「ボケ」として描画するかも品質を左右します。

        - CIBoxBlur
        - CIDiscBlur
        - CIGaussianBlur
        - CIMaskedVariableBlur
        - CIZoomBlur
        - CIMotionBlur
        - CIBokehBlur
        """
      )
    }
  }

  var script: String = """
    深度マップが得られたあと、それをどう「ボケ」として描画するかも品質を左右する要素です。
    Core ImageのBlur系フィルタ、CIBoxBlur、CIDiscBlur、CIGaussianBlur、CIMaskedVariableBlur、CIZoomBlur、CIMotionBlur、CIBokehBlurを深度ベースのボケ描画に使って、それぞれの見え方を比較しました。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    BokehBlurComparison()
  }
}
