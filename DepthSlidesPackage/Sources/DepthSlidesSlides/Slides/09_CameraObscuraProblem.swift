import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct CameraObscuraProblem: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # カメラ・オブスキュラ（ピンホールカメラ）の問題

        - ピントという概念はないがボヤけた感じになる
        - 光量が少ない
          - 対策としてレンズを利用
          - 虫眼鏡のような凸レンズがよく利用された
        - ピントを調整する必要
        """
      )
    }
  }

  var script: String = """
    カメラ・オブスキュラの問題についてお話しします。
    このような穴を開けただけのカメラをピンホールカメラと言いますが、これらはピントという概念はありません。
    しかしボヤけた感じになります。
    また、カメラ・オブスキュラは小さな点からの光を取り入れるので光量が少ないという問題があります。
    それを解決するために、光を集めるレンズが利用されるようになりました。
    レンズには虫眼鏡のような凸レンズが利用されました。
    これにより明るい映像を獲得することができましたが、ピントを合わせる必要が出てきました。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    CameraObscuraProblem()
  }
}
