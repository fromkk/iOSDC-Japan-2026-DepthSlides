import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct BokehBlurComparison: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # 様々なボケを試して最適なものを選ぶ

        - CIBoxBlur
          - 正方形の範囲のピクセルから色の中央値を求めてぼかす（radius は正方形の幅）
        - CIDiscBlur
          - radius で指定した円の中のピクセルから色の中央値を求めてぼかす
        - CIGaussianBlur
          - radius で指定した円の中を、ガウス分布に従って中心から外側へぼかす
        - CIMaskedVariableBlur
          - グレースケールのマスクでぼかしの強さを変える（黒はぼかさず、白が最大）
        - CIZoomBlur
          - center を中心に amount 分ズームしたようなブレを加える
        - CIMotionBlur
          - angle（ラジアン）で指定した方向へ radius ピクセル分ブレを伸ばす
        - CIBokehBlur
          - 円形のボケに ringSize / ringAmount のリング状の強調と softness を加える
        """
      )
    }
  }

  var script: String = """
    最後に、ボケの作り方です。Core Image には様々なブラーのフィルターが用意されています。Apple のドキュメントを見ると、それぞれ適用されるボケが違うことが分かります。
    CIBoxBlur は正方形の範囲のピクセルから色の中央値を求めてぼかすもので、radius はその正方形の幅になります。CIDiscBlur は同じく中央値を使いますが、範囲が radius で指定した円になります。
    CIGaussianBlur は円の中をガウス分布に従って中心から外側へぼかすもので、一番よく使われるブラーです。
    CIMaskedVariableBlur はグレースケールのマスク画像でぼかしの強さを場所ごとに変えられるもので、黒い部分はぼかさず、白い部分が最大のボケになります。深度マップをそのままマスクとして使えるのがポイントです。
    CIZoomBlur は center を中心に amount 分ズームしたようなブレ、CIMotionBlur は angle で指定した方向へ radius ピクセル分ブレを伸ばすもので、これらはボケというより演出寄りですね。
    そして CIBokehBlur は、円形のボケに ringSize と ringAmount でリング状の強調を、softness で柔らかさを加えられる、レンズのボケ味に一番近いフィルターです。
    これもどう違うのか、シミュレーターを作って比較してみます。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehBlurComparison()
  }
}
