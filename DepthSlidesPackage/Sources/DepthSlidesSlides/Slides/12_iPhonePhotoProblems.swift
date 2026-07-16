import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct IPhonePhotoProblems: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # iPhone で撮影した写真の問題点

        - レンズ・センサーサイズ
          - 最新の高性能な iPhone でもセンサーサイズは1/1.28インチが最大
          - 少ない光しか取り込むことができない
          - 被写界深度が深い
        - 色作り
          - iPhone で撮影した画像はよくも悪くもニュートラル
          - 全体をはっきり写すことに特化
          - 彩度が高め
          - こだわりたい人は RAW 設定で撮影することをお勧め
          - （今回は話さない）
        """
      )
    }
  }

  var script: String = """
    ここまでを踏まえて、iPhone で撮影した写真の問題点を見てみます。
    まずレンズとセンサーサイズです。最新の高性能な iPhone でもセンサーサイズは 1/1.28インチが最大で、少ない光しか取り込むことができず、被写界深度が深い、つまりボケにくいという特徴があります。
    もうひとつは色作りです。iPhone で撮影した画像はよくも悪くもニュートラルで、全体をはっきり写すことに特化していて、彩度は高めです。
    こだわりたい人は RAW 設定で撮影するのがおすすめですが、今回はここは深くは話しません。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    IPhonePhotoProblems()
  }
}
