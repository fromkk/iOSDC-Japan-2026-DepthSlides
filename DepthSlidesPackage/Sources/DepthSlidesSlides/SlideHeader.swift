import SwiftUI

/// 本編スライド共通のヘッダー。罫 + 章名 + 章内の現在地。
///
/// 見た目は作例スライド（`24_BeforeAfterResults`）が元から持っていたものに合わせて
/// ある。あちらは「作例 01 / 07」と作例の枚数を数えるので、この型は使わず自前で
/// 同じ体裁を描いている。
struct SlideHeader: View {
  @Environment(\.slideTheme) private var theme

  private let label: String
  /// 章に属さないスライド（まとめなど）では nil にして現在地を出さない。
  private let counter: String?

  init(_ slide: DeckSlide) {
    let placement = slide.placement
    self.label = placement.section.title
    self.counter = String(format: "%02d / %02d", placement.index, placement.total)
  }

  init(label: String) {
    self.label = label
    self.counter = nil
  }

  var body: some View {
    HStack {
      HStack(spacing: 28) {
        Rectangle()
          .frame(width: 64, height: 3)
        Text(label)
          .font(.system(size: 30, weight: .bold))
          .tracking(9)
      }
      .foregroundStyle(theme.primaryTextColor)

      Spacer()

      if let counter {
        Text(counter)
          .font(.system(size: 30))
          .monospacedDigit()
          .tracking(2.4)
          .foregroundStyle(theme.secondaryTextColor)
      }
    }
  }
}

/// Markdown 本文（`SlideWrapper` + `convertPage`）の上にヘッダーを足すための入れ物。
///
/// `StandardLayout` が自前で `contentPadding` を持っているので、本文側にパディングを
/// 重ねず、ヘッダーにだけ左右と上のパディングを当てている。自前でレイアウトを組んで
/// いて既にルートへパディングを当てているスライドは、この型を使わず `SlideHeader` を
/// VStack の先頭に置けばよい。
struct HeaderedSlide<Content: View>: View {
  @Environment(\.slideTheme) private var theme

  private let header: SlideHeader
  @ViewBuilder private var content: () -> Content

  init(_ slide: DeckSlide, @ViewBuilder content: @escaping () -> Content) {
    self.header = SlideHeader(slide)
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(.horizontal, theme.contentPadding)
        .padding(.top, theme.contentPadding)

      content()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

#Preview {
  VStack(spacing: 40) {
    SlideHeader(.fNumber)
    SlideHeader(.modelUsageNotes)
    SlideHeader(.bokehFilterResults)
    SlideHeader(label: "まとめ")
  }
  .padding(60)
  .frame(width: 1920)
}
