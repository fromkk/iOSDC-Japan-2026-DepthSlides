import MarkdownToSlide
import SlideKit
import SwiftUI

/// 7種類のブラー系フィルターを同じ写真に適用した結果を一覧で見せるスライド。
/// 以前はその場でパラメーターを触れるシミュレーター（`CIFilterBokehCompareView`）
/// を出していたが、違いを一目で伝えることを優先して結果の並列表示に変更した。
@Slide
struct BokehFilterResults: View {
  @Environment(\.slideTheme) var theme

  enum SlidePhase: Int, PhasedState {
    case initial
    case second
  }

  @Phase var phase: SlidePhase

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        SlideHeader(.bokehFilterResults)

        Text("フィルターごとのボケの違い")
          .font(theme.headingH3Font)
          .foregroundStyle(theme.primaryTextColor)
          .frame(maxWidth: .infinity, alignment: .leading)

        BokehFilterResultGridView(
          highlighted: phase != .initial ? .bokehBlur : nil
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .padding(theme.contentPadding)
    }
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        同じ夜景の写真に、7 種類のフィルターをかけた結果を並べてみました。窓明かりが無数の点光源になるので、ボケの形の違いがそのまま絵に出ます。違いが見えるように、半径などのパラメーターはかなり過剰に振っています。
        Box、Disc、Gaussian は一様なボケを深度マスクで合成しているので傾向は似ていますが、Box は四角いボケ、Disc は円、Gaussian はにじむように溶けます。
        MaskedVariableBlur は深度マップをそのままボケの強さに使えるので、奥に行くほど連続的にボケが強くなります。
        BokehBlur は円形のボケの縁が明るく残る、レンズに一番近いボケです。
        Zoom と Motion はブレの表現なので、やはり今回の目的には合いません。
        """
    case .second:
      return "今回はその CIBokehBlur を選びました。"
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehFilterResults()
  }
}
