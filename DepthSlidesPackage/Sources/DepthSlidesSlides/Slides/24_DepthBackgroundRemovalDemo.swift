import MarkdownToSlide
import SlideKit
import SwiftUI

/// 「時間があったら」枠のデモ。Depth Anything V2 Small の深度マップを使い、
/// タップしたオブジェクトより手前だけを残して背景を削除する。
@Slide
struct DepthBackgroundRemovalDemo: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack {
      Text("深度で背景削除デモ")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)
        .frame(maxWidth: .infinity, alignment: .leading)

      DepthBackgroundRemovalView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    せっかくなので、背景削除を実際にやってみます。さっきと同じ Depth Anything V2 Small で深度を推定して、画像をタップすると、その位置の深度を読み取ります。
    そして、タップしたオブジェクトと同じかそれより手前の画素だけを残して、奥側を背景として透過させています。市松模様になっている部分が削除されたところです。
    やっていることは CIColorMatrix で深度マップを閾値処理してマスクを作り、CIBlendWithMask で合成しているだけなので、ボケのときとほとんど同じ仕組みです。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    DepthBackgroundRemovalDemo()
  }
}
