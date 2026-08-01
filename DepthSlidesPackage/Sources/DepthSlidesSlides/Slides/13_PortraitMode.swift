import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PortraitMode: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
  }

  @Phase var phase: SlidePhase

  let converter = MarkdownToSlideConverter()

  var body: some View {
    HStack {
      SlideWrapper {
        converter.convertPage(
          """
          # Portrait mode

          - 2016年10月配信の iOS 10.1 で初登場（iPhone 7 Plus）
          - 当初はデュアルカメラの視差から深度を推定して、撮影したい対象以外のボケを生成
          - iPhone 12 Pro 以降は LiDAR スキャナも活用され、深度の精度が向上
          - 当初は Portrait mode にわざわざ変更する必要があった
            - 最近は普通に撮影して後で f値 を変更することも可能
          - 撮影した写真によってはボケに違和感があることも
          """
        )
      }

      switch phase {
      case .initial:
        Image(.IMG_2581)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 400)
      case .second:
        Image(.IMG_1606)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 400)
      }
    }
  }

  var script: String = """
    そんなボケにくさを補うために登場したのが Portrait mode です。2016年10月配信の iOS 10.1 で、iPhone 7 Plus 向けに初登場しました。
    当初はデュアルカメラの視差から深度を推定して、撮影したい対象以外にボケを生成していました。iPhone 12 Pro 以降は LiDAR スキャナも活用されて、深度の精度が上がっています。
    当初はわざわざ Portrait mode に切り替えて撮影する必要がありましたが、最近は普通に撮影して、あとから f値を変更することもできます。
    ただ、撮影した写真によってはボケに違和感があることもあります。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview("initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<PortraitMode.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    PortraitMode()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("second") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<PortraitMode.SlidePhase>(.second)
  }
  let controller = SlideIndexController(container: container) {
    PortraitMode()
  }
  return SlideRouterView(slideIndexController: controller)
}
