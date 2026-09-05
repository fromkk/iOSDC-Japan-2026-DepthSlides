import MarkdownToSlide
import SlideKit
import SwiftUI

/// extension DC 2026 の宣伝。Day1 / Day2 の 2 日開催なので、
/// 日程を見比べられるよう横並びのカードで見せる。
/// QR は URL から `QRCodeGenerator` で生成するので画像アセットは持たない。
@Slide
struct ExtensionDCPR: View {
  @Environment(\.slideTheme) var theme

  struct Day: Identifiable {
    let id: String
    let name: String
    let date: String
    let venue: String
    let url: String
  }

  static let days: [Day] = [
    Day(
      id: "day1",
      name: "Day1",
      date: "9/18(金) 19:00〜22:00",
      venue: "LINEヤフー 赤坂オフィス",
      url: "https://extension-dc.connpass.com/event/391184/"),
    Day(
      id: "day2",
      name: "Day2",
      date: "9/19(土) 12:30〜19:00",
      venue: "六本木ヒルズ某所",
      url: "https://extension-dc.connpass.com/event/391185/"),
  ]

  var body: some View {
    VStack(spacing: 16) {
      Image(.extensionDc)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))

      HStack(alignment: .top, spacing: 32) {
        ForEach(Self.days) { day in
          dayCard(day)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(theme.contentPadding)
  }

  private func dayCard(_ day: Day) -> some View {
    VStack(spacing: 12) {
      Text(day.name)
        .font(.system(size: 40, weight: .bold))
        .foregroundStyle(theme.primaryTextColor)

      Text(day.date)
        .font(.system(size: 30))
        .foregroundStyle(theme.primaryTextColor)

      Text(day.venue)
        .font(.system(size: 26))
        .foregroundStyle(theme.secondaryTextColor)
        .multilineTextAlignment(.center)

      if let qr = QRCodeGenerator.image(for: day.url) {
        Image(decorative: qr, scale: 1)
          .resizable()
          .interpolation(.none)
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      Text(day.url)
        .font(.system(size: 18))
        .foregroundStyle(theme.secondaryTextColor)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
    .background(RoundedRectangle(cornerRadius: 16).fill(theme.tableBackgroundColor))
  }

  var script: String = """
    ここから宣伝です。まず来週の9月18日金曜の夜と19日土曜に、extension DC 2026 を2日間で開催します。
    直近のカンファレンスの振り返りや、話したかったけど話せなかったトークを話す場所として用意できればと思っています。
    登壇枠も参加枠もまだありますので是非ご参加ください。
    Day 1はLYさん、Day 2はAppleさんのオフィスをお借りします。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    ExtensionDCPR()
  }
}
