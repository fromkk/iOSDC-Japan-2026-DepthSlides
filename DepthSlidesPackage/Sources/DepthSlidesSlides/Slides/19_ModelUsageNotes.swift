import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct ModelUsageNotes: View {
  @Environment(\.slideTheme) var theme

  /// 補足は 2 列（1 列 856pt）で 1 行に収まる長さにしてある。伸ばすと 2 行に割れて
  /// 項目ごとの高さが揃わなくなる。詳細は `script` 側で喋る。
  private static let points: [SlidePoint] = [
    SlidePoint("Core ML / Core AI 用に変換が必要", "Core AI は Core ML の後継（Xcode 27 / iOS 20 SDK）"),
    SlidePoint("モデルのサイズが大きい", "アプリに同梱するぶん、アプリのサイズも増える"),
    SlidePoint("Depth Pro は Mac 並みの性能が要る", "とくにメモリを要求する"),
    SlidePoint("ライセンスがモデルごとに違う", "同じモデルでもサイズによって商用可否が変わる"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 40) {
      SlideHeader(.modelUsageNotes)

      Text("配布されているモデルを利用する際の注意点")
        .font(theme.headingH2Font)
        .foregroundStyle(theme.primaryTextColor)

      SlidePointList(points: Self.points, columns: 2)

      Spacer(minLength: 0)
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  var script: String = """
    配布されているモデルを使う際には、いくつか注意点があります。
    まず、それぞれ Core ML や Core AI で利用するためにモデルの変換が必要です。Core AI は WWDC26 で発表された Core ML の後継フレームワークで、Xcode 27 / iOS 20 SDK から利用できます。
    また、モデルのサイズが大きいので、アプリに同梱するとアプリのサイズも大きくなってしまいます。
    さらに Depth Pro は Mac 並みの性能、特にメモリが必要です。
    また、ライセンスもモデル自体や、モデルのサイズによって異なりますので、高性能で使いたくても使えないものもありますので注意が必要です。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    ModelUsageNotes()
  }
}
