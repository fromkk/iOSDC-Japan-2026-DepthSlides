import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct Summary: View {
  @Environment(\.slideTheme) var theme

  private static let recap: [String] = [
    "カメラの歴史と仕組みを振り返る",
    "写真に内蔵された深度情報を取得する",
    "配布されているモデルで深度を推定する",
    "ボケのフィルターを比較する",
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 56) {
      SlideHeader(label: "まとめ")

      HStack(alignment: .top, spacing: 88) {
        // 左は復習なので secondary に落として、視線が右の結論に行くようにする。
        VStack(alignment: .leading, spacing: 36) {
          eyebrow("今日やったこと")

          VStack(alignment: .leading, spacing: 28) {
            ForEach(Self.recap, id: \.self) { item in
              Text(item)
                .font(.system(size: 40))
                .foregroundStyle(theme.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Rectangle()
          .fill(theme.secondaryTextColor.opacity(0.4))
          .frame(width: 2)

        // 「今回これを選びました」が箇条書きの 5 行目に埋もれていたのを引き上げる。
        VStack(alignment: .leading, spacing: 36) {
          eyebrow("今回の選択")

          VStack(alignment: .leading, spacing: 48) {
            choice(label: "モデル", value: "Depth Anything V3\n（da3-small）")
            choice(label: "フィルター", value: "CIBokehBlur")
          }
        }
        .frame(width: 780, alignment: .leading)
      }
      .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 30, weight: .semibold))
      .tracking(4.2)
      .foregroundStyle(theme.secondaryTextColor)
  }

  private func choice(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(label)
        .font(.system(size: 30))
        .foregroundStyle(theme.secondaryTextColor)
      Text(value)
        .font(theme.headingH3Font)
        .foregroundStyle(theme.primaryTextColor)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  var script: String = """
    まとめです。今日はカメラの歴史と仕組みを振り返り、写真に内蔵されている深度情報を取得し、配布されているモデルで深度を推定して、ボケのフィルターを比較してみました。
    その結果、今回僕はモデルに Depth Anything V3 の da3-small を、フィルターに CIBokehBlur を選びました。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    Summary()
  }
}
