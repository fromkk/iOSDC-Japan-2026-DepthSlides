import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct IPhonePhotoProblems: View {
  @Environment(\.slideTheme) var theme

  private static let points: [SlidePoint] = [
    SlidePoint("センサーが小さい", "被写界深度が深くなり、そもそもボケにくい"),
    SlidePoint("全体をはっきり写す絵作り", "どこにもピントが合っているように見せにいく"),
    SlidePoint("主題が背景に埋もれる", "結果として情報量の多い、散らかった写真になりがち"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 40) {
      SlideHeader(.iPhonePhotoProblems)

      // 写真を 520pt に抑えて本文カラムを 1240pt 確保している。ここを広げると
      // 72pt のタイトルが 2 行に折り返す。
      HStack(alignment: .top, spacing: 60) {
        VStack(alignment: .leading, spacing: 44) {
          Text("スマホで撮影した写真の問題点")
            .font(theme.headingH2Font)
            .foregroundStyle(theme.primaryTextColor)
            .fixedSize(horizontal: false, vertical: true)

          SlidePointList(points: Self.points)

          Spacer(minLength: 0)
        }

        Image(.IMG_2569)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .frame(width: 520)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  var script: String = """
    ここまでの話を踏まえて、スマホで撮影した写真を見てみると、センサーが小さいので被写界深度が深く、ボケにくいという特徴があります。
    さらに全体をはっきり写すことに特化した絵作りなので、最初のひまわりのように主題が背景に埋もれて、情報量の多い写真になりがちです。
    """

  var transition: AnyTransition = AnyTransition.awesome
}
