import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct BokehOptics: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # ボケの光学的な原理

        - ボケを生むのは「絞りの実直径」
        - F値 = 焦点距離 ÷ 絞りの実直径
        - 画角を揃える焦点距離はセンサーサイズに比例する
        - センサーが小さいiPhoneは、同じF値表記でも絞りの実直径が小さい
        - 光学的に同等のボケを作るのは原理的に難しい
        """
      )
    }
  }

  var script: String = """
    ボケを生むのは「絞りの実直径」です。
    F値は焦点距離を絞りの実直径で割った値で表されます。
    画角を揃えるための焦点距離はセンサーサイズに比例するため、センサーが小さいiPhoneは同じF値表記でも絞りの実直径が小さくなります。
    つまり、光学的に同等のボケを作るのは原理的に難しいという制約があります。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    BokehOptics()
  }
}
