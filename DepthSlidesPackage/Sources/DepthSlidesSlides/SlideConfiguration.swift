import EventPRSlides
import SlideKit
import SwiftUI

@MainActor
public struct SlideConfiguration {
  public let size = SlideSize.standard16_9

  // 末尾の宣伝パートは `EventPRSlides` ターゲットに切り出してあり、宣伝だけの
  // 単体アプリ（EventPR）と共有している。`@Slide` の生成メンバーが public に
  // ならず型を公開できないため、`EventPRDeck.slides` から `[any Slide]` として
  // 受け取って連結する（result builder ではなく `SlideIndexController(slides:)`）。
  public let slideIndexController = SlideIndexController(
    slides: mainSlides + EventPRDeck.slides)

  private static var mainSlides: [any Slide] {
    [
      // 第0幕: つかみとゴール
      TitleSlide(),
      PhotoComparison(),
      GoalSlide(),
      ProfileSlide(),
      AnnounceSlide(),
      // 第1幕: なぜ iPhone はボケないか
      CameraObscuraOrigin(),
      AboutLens(),
      ConvexLensSimulation(),
      FNumber(),
      FNumberDemo(),
      SensorSize(),
      IPhonePhotoProblems(),
      IPhonePhotoTips(),
      PortraitMode(),
      // 第2幕: 自分で作る（深度を得る → ボカす）
      BokehImprovementApproaches(),
      DepthSectionDivider(),
      EmbeddedDepth(),
      ModelComparison(),
      ModelUsageNotes(),
      DepthModelSimulator(),
      BokehSectionDivider(),
      BokehBlurComparison(),
      BokehFilterResults(),
      // 第3幕: 結論
      Summary(),
      ToneCraftAnnounce(),
      ReferenceBook(),
      DepthOtherUseCases(),
      DepthBackgroundRemovalDemo(),
    ]
  }

  public init() {}
}

#Preview {
  let configuration = SlideConfiguration()
  SlideScreen(slideSize: configuration.size) {
    SlideRouterView(slideIndexController: configuration.slideIndexController)
  }
}
