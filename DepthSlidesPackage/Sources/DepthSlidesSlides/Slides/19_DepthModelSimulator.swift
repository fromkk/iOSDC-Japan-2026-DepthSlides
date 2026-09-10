import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct DepthModelSimulator: View {
  @Environment(\.slideTheme) var theme
  let converter = MarkdownToSlideConverter()

  var body: some View {
    VStack {
      SlideHeader(.depthModelSimulator)

      Text("モデル比較シミュレーター")
        .font(theme.headingH2Font)
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
    写真を読み込むと、左上に元の写真、その隣から写真に埋め込まれた深度と、それぞれのモデルで推定した深度が一覧で並びます。推論が終わったものから順に表示されます。
    写真に含まれている深度を見ると細かい情報が抜け落ちていることがわかります。
    一方で Depth Anything はそこそこ詳細情報を持っていることがわかりますし、Depth Proに至っては鮮明な深度情報であることがわかります。
    気になるものはタップすると拡大して、元の写真と見比べられます。
    下のセグメントを切り替えると、モデルの入手・変換のコードと、推論のコードもモデルごとに並べて見られます。
    ここの精度がボケを加える際の精度に繋がります。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    DepthModelSimulator()
  }
}
