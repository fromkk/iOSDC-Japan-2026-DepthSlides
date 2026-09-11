import EventPRSlides
import SlideKit
import SwiftUI

/// ToneCraft 告知の後ろに置く余談。前半で話したレンズ・絞りの話を、
/// 実際に 3D プリンターで作ってみた記事に繋げる。
/// QR は URL から `QRCodeGenerator` で生成するので画像アセットは持たない。
@Slide
struct HandmadeLens: View {
  @Environment(\.slideTheme) var theme

  static let url = "https://note.com/fromkk/n/nccfcc581863e"

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      HStack(alignment: .top, spacing: 64) {
        Image(.note)
          .resizable()
          .scaledToFit()

        VStack(spacing: 16) {
          if let qr = QRCodeGenerator.image(for: Self.url) {
            Image(decorative: qr, scale: 1)
              .resizable()
              .interpolation(.none)
              .aspectRatio(contentMode: .fit)
              .frame(width: 300, height: 300)
          }
          Text(Self.url)
            .font(.system(size: 28))
            .foregroundStyle(theme.secondaryTextColor)
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .padding(theme.contentPadding)
  }

  var script: String = """
    前半でレンズと絞りの話をしましたが、実はこの登壇の準備中に、勉強がてら3D プリンターでレンズそのものを自作してみました。
    ここに実物がありますので、興味のある方は声をかけてください。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    HandmadeLens()
  }
}
