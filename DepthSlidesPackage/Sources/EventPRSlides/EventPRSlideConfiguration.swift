import SlideKit
import SwiftUI

/// 宣伝スライドだけを並べた単体アプリ（`EventPR`）用の構成。
/// 登壇資料本体（`DepthSlidesSlides.SlideConfiguration`）も同じ
/// `EventPRDeck.slides` を末尾に並べるので、スライドの実体は一箇所で管理される。
@MainActor
public struct EventPRSlideConfiguration {
  public let size = SlideSize.standard16_9

  public let slideIndexController = SlideIndexController(slides: EventPRDeck.slides)

  public init() {}
}

#Preview {
  let configuration = EventPRSlideConfiguration()
  SlideScreen(slideSize: configuration.size) {
    SlideRouterView(slideIndexController: configuration.slideIndexController)
  }
}
