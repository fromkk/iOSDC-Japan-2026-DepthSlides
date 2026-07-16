import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct FNumberDemo: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      // TODO: 絞りの開閉とボケの大きさが連動するデモを実装する
      converter.convertPage(
        """
        # f値デモ

        （絞りを開けるとボケが大きくなり、絞りを閉じるとボケが小さくなる様子を見せる）
        """
      )
    }
  }

  var script: String = """
    実際に見てみましょう。絞りを開けるとボケが大きくなり、絞りを閉じるとボケが小さくなります。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    FNumberDemo()
  }
}
