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
        # カメラ・オブスキュラの問題
        """
      )
    }
  }

  var script: String = """
    カメラ・オブスキュラは小さな点からの光を取り入れるので光量が少ないという問題があります。
    それを解決するために光を集めるためにレンズが利用されるようになりました。
    レンズには虫眼鏡のような凸レンズが利用されました。
    これにより明るい映像を獲得することができましたが、ピントを合わせる必要が出てきました。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    CameraObscuraProblem()
  }
}
