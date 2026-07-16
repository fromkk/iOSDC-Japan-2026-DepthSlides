import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PhotoComparison: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      // TODO: iPhone で撮った写真とミラーレス一眼で撮影した画像を並べて表示する
      converter.convertPage(
        """
        （iPhone で撮った写真とミラーレス一眼で撮影した画像を比較する）
        """
      )
    }
  }

  var script: String = """
    普段写真を撮っていて「なんかパッとしないな」「もっとよく撮れるはずなんだけどな」と思うことはないでしょうか？
    それは腕が悪いのか、iPhoneが悪いのか、いいカメラを使えばいいのか、今日はそんな問題を解消できないかと試行錯誤した内容についてお話しします。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    PhotoComparison()
  }
}
