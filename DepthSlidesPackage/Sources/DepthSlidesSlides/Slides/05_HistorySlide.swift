import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct HistorySlide: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # iOSDC Japan 登壇歴

        - 2017 自分が欲しいとアプリを作った LT
        - 2018 ツールとして利用するUIテスト 15min
        - 2019 iOS 12以下でDark modeに対応した地獄の話 LT
        - 2020 Catalystに対応したアプリをリリースするまでのリジェクト集 LT
        - 2020 iOSには無いmacOS独自機能をCatalystで実装する 20min
        - 2021 noteのiOSアプリで実装したアクセシビリティの全て 20min
        - 2022 ノートアプリのテキストエディタの解体新書 20min
        - 2025 独自UIで実現する外部ストレージデバイスの読み書き 20min
        """
      )
    }
  }

  var script: String = """
    過去に登壇した履歴です。
    もし興味があれば過去のYouTubeなどで見ていただければと思います。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    HistorySlide()
  }
}
