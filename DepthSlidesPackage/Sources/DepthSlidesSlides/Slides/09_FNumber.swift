import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct FNumber: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # f値

        - レンズを使うと明るすぎる問題がある
          - 拡散や収差の問題で画像がにじんでしまう
          - 明るすぎると被写界深度が浅くなる
            - ピントを合わせるのが大変
            - ピントが合わない箇所（ボケ）が大きくなる
        - 絞りを使うことで入る光を制限する
          - 被写界深度を深くすることができる
          - ピントを合わせるのが簡単になる
          - ピントが合わない箇所（ボケ）が小さくなる
        - f値 = 焦点距離 / 絞りの実直径
        """
      )
    }
  }

  var script: String = """
    レンズで光を集められるようになると、今度は明るすぎるという問題が出てきます。
    拡散や収差の影響で画像がにじんでしまったり、被写界深度が浅くなってピントを合わせるのが大変になったり、ピントが合わない箇所、つまりボケが大きくなったりします。
    そこで絞りを使って、入ってくる光を制限します。
    絞ることで被写界深度が深くなり、ピントを合わせるのが簡単になって、ボケも小さくなります。
    この絞り具合を表すのが f値 で、焦点距離を絞りの実直径で割った値です。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    FNumber()
  }
}
