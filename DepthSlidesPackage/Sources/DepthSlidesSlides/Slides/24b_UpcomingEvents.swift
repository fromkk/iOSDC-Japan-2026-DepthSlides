import MarkdownToSlide
import SlideKit
import SwiftUI

/// Saitama.swift の宣伝（`25_SaitamaSwiftPR`）の前に、先に開催される
/// コミュニティイベントをまとめて宣伝するスライド。
/// QR は URL から `QRCodeGenerator` で生成するので画像アセットは持たない。
@Slide
struct UpcomingEvents: View {
  @Environment(\.slideTheme) var theme

  struct Event: Identifiable {
    let id: String
    let name: String
    let date: String
    let venue: String
    let url: String
  }

  static let events: [Event] = [
    Event(
      id: "extension-dc-day1",
      name: "extension DC 2026 Day1",
      date: "9/18(金) 19:00〜22:00",
      venue: "LINEヤフー 赤坂オフィス",
      url: "https://extension-dc.connpass.com/event/391184/"),
    Event(
      id: "extension-dc-day2",
      name: "extension DC 2026 Day2",
      date: "9/19(土) 12:30〜19:00",
      venue: "六本木ヒルズ某所",
      url: "https://extension-dc.connpass.com/event/391185/"),
    Event(
      id: "kanagawa-swift-3",
      name: "Kanagawa.swift #3",
      date: "10/31(土) 12:00〜21:00",
      venue: "Hamee 株式会社 (小田原)",
      url: "https://japan-region-swift.connpass.com/event/389036/"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("PR  この先のイベント")
        .font(theme.headingH3Font)
        .foregroundStyle(theme.primaryTextColor)

      HStack(alignment: .top, spacing: 32) {
        ForEach(Self.events) { event in
          eventCard(event)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(theme.contentPadding)
  }

  private func eventCard(_ event: Event) -> some View {
    VStack(spacing: 12) {
      Text(event.name)
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(theme.primaryTextColor)
        .multilineTextAlignment(.center)

      Text(event.date)
        .font(.system(size: 28))
        .foregroundStyle(theme.primaryTextColor)

      Text(event.venue)
        .font(.system(size: 24))
        .foregroundStyle(theme.secondaryTextColor)
        .multilineTextAlignment(.center)

      if let qr = QRCodeGenerator.image(for: event.url) {
        Image(decorative: qr, scale: 1)
          .resizable()
          .interpolation(.none)
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      Text(event.url)
        .font(.system(size: 16))
        .foregroundStyle(theme.secondaryTextColor)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
    .background(RoundedRectangle(cornerRadius: 16).fill(theme.tableBackgroundColor))
  }

  var script: String = """
    ここから宣伝です。まずこの先のイベントを3つ紹介させてください。
    9月18日金曜の夜と19日土曜に、extension DC 2026 を Day1・Day2 の2日間で開催します。2026年上半期に発表・注目されたトピックを振り返る内容で、どちらも参加費無料です。
    10月31日土曜には、小田原の Hamee さんで Kanagawa.swift #3 があります。こちらはお弁当と懇親会つきです。
    どれも気になるものがあれば QR から見てみてください。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    UpcomingEvents()
  }
}
