import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct DepthDataAcquisition: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    HStack {
      SlideWrapper {
        converter.convertPage(
          """
          # 写真に含まれる深度情報を取得

          ```swift
          let source = CGImageSourceCreateWithData(data as CFData, nil)!
          let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
            source, 0, kCGImageAuxiliaryDataTypeDisparity
          ) as! [AnyHashable: Any]

          let depthData = try AVDepthData(fromDictionaryRepresentation: info)
          let converted = depthData.converting(
            toDepthDataType: kCVPixelFormatType_DisparityFloat32
          )
          let depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)
          ```
          """
        )
      }

      DepthImagePickerView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  var script: String = """
    まずは写真に含まれる深度情報を取得してみます。コードはこのようになります。
    取得した深度は、このような画像として可視化できます。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    DepthDataAcquisition()
  }
}
