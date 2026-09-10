import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct ProfileSlide: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # Profile
        ```
        struct Profile {
          let name = "Kazuya Ueoka"
          let job = "iOS Developer"
          let x = "@fromkk"
          let github = "fromkk"
          let note = "fromkk"
          let basedOn = "Saitama, Japan"
          let favorite = "Photography"
        }
        ```
        """
      )
    }
  }

  var script: String = """
    自己紹介です。
    植岡　和哉と申します。
    iOSアプリを作る仕事をしています。
    インターネットでは @fromkk というアカウントで活動しているのでよかったらフォローしてください。
    カメラで写真を撮るのが好きです。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    ProfileSlide()
  }
}
