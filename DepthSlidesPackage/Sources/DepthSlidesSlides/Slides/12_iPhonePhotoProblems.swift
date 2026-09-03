import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct IPhonePhotoProblems: View {
  @Environment(\.slideTheme) var slideTheme
  let converter = MarkdownToSlideConverter()

  var body: some View {
    HStack(alignment: .top) {
      SlideWrapper {
        converter.convertPage(
          """
          # iPhone で撮影した写真の問題点

          - センサーが小さい → 被写界深度が深い → **ボケにくい**
          - 全体をはっきり写すことに特化した絵作り
          - 主題が背景に埋もれて、情報量が多い写真になりがち
          """
        )
      }

      Image(.IMG_2569)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: 600)
        .padding(.trailing, slideTheme.contentPadding)
        .padding(.vertical, slideTheme.contentPadding)
    }
  }

  var script: String = """
    ここまでの話を踏まえて、iPhone で撮影した写真を見てみると、センサーが小さいので被写界深度が深く、ボケにくいという特徴があります。
    さらに全体をはっきり写すことに特化した絵作りなので、最初のひまわりのように主題が背景に埋もれて、情報量の多い写真になりがちです。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    IPhonePhotoProblems()
  }
}
