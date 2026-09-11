import SlideKit
import SwiftUI

/// まとめの直後に置く参考情報。今日話した光学の入門としておすすめの書籍を紹介する。
@Slide
struct ReferenceBook: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("参考書籍")
          .font(theme.headingH1Font)

        HStack(spacing: 40) {
          Image(.opticsBook)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          VStack(spacing: 16) {
            Text("カメラとレンズのしくみがわかる光学入門")
              .font(theme.bodyFont)
              .multilineTextAlignment(.center)
            Text("安藤幸司 著 / インプレス")
              .font(theme.headingH6Font)
            Image(.opticsBookQr)
              .resizable()
              .interpolation(.none)
              .aspectRatio(contentMode: .fit)
              .frame(width: 300, height: 300)
            Text("https://amzn.to/4gWqVue")
              .font(theme.headingH6Font)
          }
          .frame(width: 640)
        }
      }
      .padding(theme.contentPadding)
    }
  }

  var script: String = """
    参考情報です。今日話したカメラやレンズの仕組みは、この「カメラとレンズのしくみがわかる光学入門」という本がとてもわかりやすいので、興味があればぜひ読んでみてください。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    ReferenceBook()
  }
}
