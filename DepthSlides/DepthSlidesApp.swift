import MarkdownToSlide
import DepthSlidesSlides
import SlideKit
import SwiftUI

#if !canImport(UIKit)
  @main
#endif
struct DepthSlidesApp: App {
  private static let configuration = SlideConfiguration()
  let theme: MarkdownToSlide.SlideTheme = .default

  var presentationContentView: some View {
    SlideRouterView(
      slideIndexController: Self.configuration.slideIndexController
    )
  }

  var body: some Scene {
    WindowGroup {
      PresentationView(slideSize: Self.configuration.size) {
        ZStack {
          theme.backgroundColor
          presentationContentView
        }
      }
      .slideTheme(theme)
    }
    #if os(macOS)
      .windowStyle(.hiddenTitleBar)
      .commands {
        PresenterCommands(slideIndexController: Self.configuration.slideIndexController)
      }
    #endif
    #if os(macOS)
      WindowGroup("Presenter", id: "presenter") {
        macOSPresenterView(
          slideSize: Self.configuration.size,
          slideIndexController: Self.configuration.slideIndexController
        ) {
          SlideRouterView(slideIndexController: Self.configuration.slideIndexController)
        }
      }
    #endif
  }
}
