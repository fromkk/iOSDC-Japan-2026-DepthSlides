import MarkdownToSlide
import SlideKit
import SwiftUI

/// Kanagawa.swift #3 の宣伝。`SaitamaSwiftPR` と同じ「バナー + QR を横並びにして
/// 下に情報を置く」レイアウトに揃えている。QR は URL から
/// `QRCodeGenerator` で生成するので画像アセットは持たない。
@Slide
struct KanagawaSwiftPR: View {
  @Environment(\.slideTheme) var theme

  static let url = "https://japan-region-swift.connpass.com/event/389036/"

  var body: some View {
    VStack {
      HStack {
        Image(.kanagawaSwift)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        if let qr = QRCodeGenerator.image(for: Self.url) {
          Image(decorative: qr, scale: 1)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
        }
      }

      Text("10/31(土) 12:00〜21:00 / Hamee 株式会社（小田原）")
        .font(theme.bodyFont)

      Text(Self.url)
        .font(theme.bodyFont)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    続いて10月31日土曜には、小田原の Hamee さんで Kanagawa.swift #3 があります。
    まだ若干名枠があるので興味のある方はご参加ください。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    KanagawaSwiftPR()
  }
}
