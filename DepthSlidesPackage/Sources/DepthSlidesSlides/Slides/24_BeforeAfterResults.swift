import MarkdownToSlide
import SlideKit
import SwiftUI

/// まとめの直前に置く作例。今日の手順（深度を推定して CIBokehBlur をかける）を
/// 通した写真を、元の写真と並べて1組ずつ見せる。
///
/// 左右は同じ幅のカラムに `.fit` で収めるので、ペアの縦横比が同じであれば
/// 必ず同じ大きさで描かれる。作例は全組ペアで同寸のものを用意している。
@Slide
struct BeforeAfterResults: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
    case third
    case fourth
    case fifth
    case sixth
    case seventh
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme

  private struct ResultPair {
    let before: ImageResource
    let after: ImageResource
  }

  /// 元写真のファイル名順。ただし最後の1組だけは冒頭の
  /// 「どっちが iPhone で撮影したでしょう？」で使った写真なので、
  /// 締めに持ってきている。
  private static let pairs: [ResultPair] = [
    ResultPair(before: .result01Before, after: .result01After),
    ResultPair(before: .result06Before, after: .result06After),
    ResultPair(before: .result02Before, after: .result02After),
    ResultPair(before: .result03Before, after: .result03After),
    ResultPair(before: .result04Before, after: .result04After),
    ResultPair(before: .result05Before, after: .result05After),
    ResultPair(before: .result07Before, after: .result07After),
  ]

  private var pair: ResultPair { Self.pairs[phase.rawValue] }

  var body: some View {
    VStack(spacing: 24) {
      HStack {
        HStack(spacing: 28) {
          Rectangle()
            .frame(width: 64, height: 3)
          Text("作例")
            .font(.system(size: 30, weight: .bold))
            .tracking(9)
        }

        Spacer()

        Text(String(format: "%02d / %02d", phase.rawValue + 1, Self.pairs.count))
          .font(.system(size: 30))
          .monospacedDigit()
          .tracking(2.4)
          .foregroundStyle(theme.secondaryTextColor)
      }

      // 2枚は幅いっぱいに広げず、実寸のまま中央に寄せる。カラムを greedy に
      // すると縦位置の作例で左右がそれぞれの半分の中央に寄ってしまい、
      // ペアの間が大きく空いて見比べにくくなる。
      HStack(spacing: 40) {
        column(image: pair.before, label: "Before", caption: "元の写真")
        column(
          image: pair.after, label: "After", caption: "DA3-SMALL → CIBokehBlur ＋ ToneCraft で色味調整")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func column(image: ImageResource, label: String, caption: String) -> some View {
    VStack(spacing: 24) {
      // 横位置の作例は幅で頭打ちになり、枠の下側が余る。画像を枠の下端に
      // 寄せて、余りは見出しとの間に逃がす（ラベルを写真に貼り付けておく）。
      Image(image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxHeight: .infinity, alignment: .bottom)

      HStack(alignment: .firstTextBaseline, spacing: 20) {
        Text(label)
          .font(.system(size: 40, weight: .medium))
        Text(caption)
          .font(.system(size: 30))
          .foregroundStyle(theme.secondaryTextColor)
      }
    }
  }

  var script: String = """
    ここまでの方法で実際に処理してみた写真です。左が元の写真、右が DA3-SMALL で深度を推定して CIBokehBlur をかけたものです。
    ボケだけでなく色味も変わって見えると思いますが、これは自作しているToneCraftというアプリで編集をしています。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview("initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<BeforeAfterResults.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    BeforeAfterResults()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("seventh") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<BeforeAfterResults.SlidePhase>(.seventh)
  }
  let controller = SlideIndexController(container: container) {
    BeforeAfterResults()
  }
  return SlideRouterView(slideIndexController: controller)
}
