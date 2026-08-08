import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct BokehFilterSimulator: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack {
      Text("ボケフィルター比較シミュレーター")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)
        .frame(maxWidth: .infinity, alignment: .leading)

      CIFilterBokehCompareView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    実際にシミュレーターを使って、フィルターごとの違いを見てみましょう。
    CIBoxBlur、CIDiscBlur、CIGaussianBlur、CIMaskedVariableBlur、CIZoomBlur、CIMotionBlur、CIBokehBlur を切り替えて、それぞれのパラメーターも調整しながら見た目を比較できます。
    CIMaskedVariableBlur だけは深度マップをそのままボケの強さとして使えますが、それ以外は画像全体に一様なボケをかけてから深度マップで合成しているので、境目の出方や自然さがフィルターによって変わってきます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    BokehFilterSimulator()
  }
}
