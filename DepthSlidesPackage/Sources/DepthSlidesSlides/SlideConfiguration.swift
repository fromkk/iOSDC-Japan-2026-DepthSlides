import SlideKit
import SwiftUI

@MainActor
public struct SlideConfiguration {
  public let size = SlideSize.standard16_9

  public let slideIndexController = SlideIndexController {
    TitleSlide()
    ProfileSlide()
    HowCameraWorks()
    BokehOptics()
    PortraitModeLimits()
    DepthBasedApproach()
    ModelComparison()
    BokehBlurComparison()
    Summary()
  }

  public init() {}
}

#Preview {
  let configuration = SlideConfiguration()
  SlideScreen(slideSize: configuration.size) {
    SlideRouterView(slideIndexController: configuration.slideIndexController)
  }
}
