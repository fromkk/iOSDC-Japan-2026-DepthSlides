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
    .padding(theme.contentPadding)
  }

  var script: String = """
    ここで写真を撮影しようと思います。
    こちらのiPhoneに向かってポーズをしてみてください。
    ハイチーズ。
    さて、実際にシミュレーターを使って、モデルごとの違いを見てみましょう。
    ここでモデルを切り替えると、それぞれの深度推定結果を比較できます。
    写真に含まれている深度を見ると細かい情報が抜け落ちていることがわかります。
    一方でDepthAnythingはそこそこ詳細情報を持っていることがわかりますし、Depth Proに至っては鮮明な深度情報であることがわかります。
    ここの精度がボケを加える際の精度に繋がります。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    DepthModelSimulator()
  }
}
