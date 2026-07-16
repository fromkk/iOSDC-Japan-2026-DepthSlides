import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct ModelUsageNotes: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # 配布されているモデルを利用する際の注意点

        - それぞれ Core ML / Core AI で利用するために変換が必要
          - Core AI は WWDC26 で発表された Core ML の後継フレームワーク（Xcode 27 / iOS 20 SDK）
        - モデルのサイズが大きい（アプリに同梱するのでアプリのサイズも大きくなる）
        - Depth Pro は Mac 並の性能（メモリー）が必要
        """
      )
    }
  }

  var script: String = """
    配布されているモデルを使う際には、いくつか注意点があります。
    まず、それぞれ Core ML や Core AI で利用するためにモデルの変換が必要です。Core AI は WWDC26 で発表された Core ML の後継フレームワークで、Xcode 27 / iOS 20 SDK から利用できます。
    また、モデルのサイズが大きいので、アプリに同梱するとアプリのサイズも大きくなってしまいます。
    さらに Depth Pro は Mac 並の性能、特にメモリーが必要です。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    ModelUsageNotes()
  }
}
