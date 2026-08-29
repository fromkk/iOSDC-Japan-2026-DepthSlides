import SlideKit
import SwiftUI

@MainActor
public struct SlideConfiguration {
  public let size = SlideSize.standard16_9

  public let slideIndexController = SlideIndexController {
    // 第0幕: つかみとゴール
    TitleSlide()
    PhotoComparison()
    GoalSlide()
    ProfileSlide()
    AnnounceSlide()
    // 第1幕: なぜ iPhone はボケないか
    CameraObscuraOrigin()
    ConvexLensSimulation()
    FNumber()
    FNumberDemo()
    SensorSize()
    IPhonePhotoProblems()
    PortraitMode()
    // 第2幕: 自分で作る（深度を得る → ボカす）
    BokehImprovementApproaches()
    DepthSectionDivider()
    EmbeddedDepth()
    ModelComparison()
    ModelUsageNotes()
    DepthModelSimulator()
    BokehSectionDivider()
    BokehBlurComparison()
    BokehFilterSimulator()
    // 第3幕: 結論
    Summary()
    ReferenceBook()
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
