import MarkdownToSlide
import SlideKit
import SwiftUI

/// まとめの後ろに置く「時間があったら」枠。深度推定がボケ以外にも
/// 使える、という余談。時間が押していたら飛ばす前提。
@Slide
struct DepthOtherUseCases: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # （Optional）深度推定はボケ以外にも使える

        - 背景削除: 手前だけ残して背景を透過・差し替え
        - オブジェクト選択: タップした位置と近い深度の領域を選択
        - その他（空間写真、フォグ / 空気遠近法、リライティング、3D 点群 / メッシュ化、AR オクルージョン、etc...）
        """
      )
    }
  }

  var script: String = """
    余談です。今日は深度をボケに使いましたが、深度が分かると他にもいろいろできます。
    例えば、手前だけ残して背景を削除したり、タップした位置と近い深度の領域をオブジェクトとして選択したり。
    深度から左右の視差を作れば Vision Pro で見られる空間写真になりますし、奥ほど霞ませるフォグや、光を当て直すリライティング、1枚の写真から点群やメッシュを起こす、AR で仮想オブジェクトの前後関係を正しく描く、といった使い道もあります。
    ボケだけでなく、深度推定自体が写真アプリの引き出しを増やしてくれる可能性があるので興味のある方はぜひ挑戦してみてください。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    DepthOtherUseCases()
  }
}
