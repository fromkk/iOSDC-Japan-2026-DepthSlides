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

        - レンズだけだと光が多すぎて、にじみや収差が出て、被写界深度も浅くなりすぎる
        - **絞り**で入る光を制限すると、被写界深度が深くなりピントが合わせやすくなる
        - f値 = 焦点距離 ÷ 絞りの実直径
          - **小さいほど開いている（ボケる）**、大きいほど絞っている（ボケない）
        """
      )
    }
  }

  var script: String = """
    レンズで光を集められるようになると、今度は明るすぎるという問題が出てきます。にじみや収差が出たり、被写界深度が浅くなりすぎてピントを合わせるのが大変になったりします。
    そこで絞りを使って、入ってくる光を制限します。絞ることで被写界深度が深くなり、ピントが合わせやすくなります。
    この絞り具合を表すのが f値 で、焦点距離を絞りの実直径で割った値です。小さいほど開いていてボケる、大きいほど絞っていてボケない、という関係です。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    FNumber()
  }
}
