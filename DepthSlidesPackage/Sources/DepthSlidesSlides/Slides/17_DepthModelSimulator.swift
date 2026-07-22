import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct DepthModelSimulator: View {
  @Environment(\.slideTheme) var theme
  let converter = MarkdownToSlideConverter()

  var body: some View {
    VStack {
      Text("モデル比較シミュレーター")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)
        .frame(maxWidth: .infinity, alignment: .leading)

      DepthModelCompareView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  var script: String = """
    実際にシミュレーターを使って、モデルごとの違いを見てみましょう。
    写真を選んで、モデルを切り替えると、それぞれの深度推定結果を比較できます。
    仕切り線をドラッグすると元画像と深度画像を見比べられ、ピンチ操作やボタンで拡大して細部も確認できます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    DepthModelSimulator()
  }
}
