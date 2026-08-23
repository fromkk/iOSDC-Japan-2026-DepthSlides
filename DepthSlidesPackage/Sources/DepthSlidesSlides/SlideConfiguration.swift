import SlideKit
import SwiftUI

@MainActor
public struct SlideConfiguration {
  public let size = SlideSize.standard16_9

  public let slideIndexController = SlideIndexController {
    TitleSlide()
    ProfileSlide()
    AnnounceSlide()
    PhotoComparison()
    AboutCamera()
    CameraObscuraOrigin()
    PinholeCameraSimulation()
    CameraObscuraProblem()
    ConvexLensSimulation()
    FNumber()
    FNumberDemo()
    SensorSize()
    IPhonePhotoProblems()
    PortraitMode()
    BokehImprovementApproaches()
    ModelUsageNotes()
    ModelComparison()
    DepthModelSimulator()
    BokehBlurComparison()
    BokehFilterSimulator()
    Summary()
    DepthOtherUseCases()
    DepthBackgroundRemovalDemo()
    SaitamaSwiftPR()
  }

  public init() {}
}

#Preview {
  let configuration = SlideConfiguration()
  SlideScreen(slideSize: configuration.size) {
    SlideRouterView(slideIndexController: configuration.slideIndexController)
  }
}
