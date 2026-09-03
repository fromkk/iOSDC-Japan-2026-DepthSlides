import EventPRSlides
import SlideKit
import SwiftUI

/// まとめの直後に置くアプリ告知。今日話した「深度を推定してボカす」が、
/// 自作アプリ ToneCraft の「フォーカスぼかし」として実際に触れることを伝える。
/// QR は URL から `QRCodeGenerator` で生成するので画像アセットは持たない。
@Slide
struct ToneCraftAnnounce: View {
  @Environment(\.slideTheme) var theme

  static let url = "https://apps.apple.com/jp/app/id6760603749"

  /// アイコンの落とす影に使う、ToneCraft のアクセントカラー（ライト）
  private let accentShadow = Color(red: 201 / 255, green: 137 / 255, blue: 122 / 255)

  var body: some View {
    HStack(alignment: .center, spacing: 80) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 28) {
          Image(.toneCraftIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 132, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: accentShadow.opacity(0.38), radius: 18, y: 14)

          VStack(alignment: .leading, spacing: 6) {
            Text("ToneCraft")
              .font(theme.headingH4Font)
            Text("写真の色補正・レタッチ")
              .font(theme.headingH6Font)
              .foregroundStyle(theme.secondaryTextColor)
          }
        }

        Spacer()

        VStack(alignment: .leading, spacing: 28) {
          Text("この機能は")
            .font(theme.headingH3Font)
            .foregroundStyle(theme.secondaryTextColor)
          Text("ToneCraft v1.5 以降で\n試せます")
            .font(theme.headingH1Font)
          Text(
            """
            「フォーカスぼかし（f ツール）」
            タップでピント位置を決めて、スライダーでボケ量を調整。処理はすべて端末内で完結します。
            """
          )
          .font(.system(size: 44))
          .foregroundStyle(theme.secondaryTextColor)
        }

        Spacer()

        HStack(spacing: 28) {
          Spacer()

          VStack(alignment: .trailing, spacing: 10) {
            Text("App Store で配信中")
              .font(theme.headingH6Font)
            Text("apps.apple.com/jp/app/id6760603749")
              .font(.system(size: 30))
              .foregroundStyle(theme.secondaryTextColor)
          }

          if let qr = QRCodeGenerator.image(for: Self.url) {
            Image(decorative: qr, scale: 1)
              .resizable()
              .interpolation(.none)
              .aspectRatio(contentMode: .fit)
              .frame(width: 200, height: 200)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

      Image(.toneCraftShot)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 460)
        .clipShape(RoundedRectangle(cornerRadius: 46))
        .shadow(color: .black.opacity(0.28), radius: 36, y: 32)
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { OldLensLightLeakBackground() }
  }

  var script: String = """
    ちなみに、今日話した深度推定とボケは、僕が作っている ToneCraft という写真編集アプリの v1.5 に「フォーカスぼかし」として入れてあります。
    写真をタップしてピント位置を決めて、スライダーでボケ量を調整するだけです。処理はすべて端末の中で完結します。
    よかったら QR から触ってみてください。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    ToneCraftAnnounce()
  }
}
