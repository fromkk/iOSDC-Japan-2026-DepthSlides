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
    最後に、ボケの作り方です。Core Image には CIBoxBlur、CIDiscBlur、CIGaussianBlur、CIMaskedVariableBlur、CIZoomBlur、CIMotionBlur、CIBokehBlur と、様々なブラーのフィルターが用意されています。
    これもどう違うのか、シミュレーターを作って比較してみます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    BokehBlurComparison()
  }
}
