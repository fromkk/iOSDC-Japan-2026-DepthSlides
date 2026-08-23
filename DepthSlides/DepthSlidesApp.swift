import DepthSlidesSlides
import MarkdownToSlide
import SlideKit
import SwiftUI

#if !canImport(UIKit)
  @main
#endif
struct DepthSlidesApp: App {
  private static let configuration = SlideConfiguration()
  private static let syncCoordinator = PresentationSyncCoordinator()
  let theme: MarkdownToSlide.SlideTheme = .default
  /// macOS Presenter ウィンドウに表示する原稿のフォントサイズ
  private static let presenterScriptFontSize: CGFloat = 20

  var presentationContentView: some View {
    SlideRouterView(
      slideIndexController: Self.configuration.slideIndexController
    )
    .task {
      Self.syncCoordinator.start(attachingTo: Self.configuration.slideIndexController)
      // モデル比較スライドを開く前に、未永続化のモデルのコンパイルを裏で
      // 済ませておく（永続化済みならすぐ抜ける）。
      await warmUpDepthModelCompilation()
    }
    .environment(\.presentationSyncCoordinator, Self.syncCoordinator)
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
      .preferredColorScheme(.light)
    }
    #if os(macOS)
      .windowStyle(.hiddenTitleBar)
      .commands {
        PresenterCommands(
          slideIndexController: Self.configuration.slideIndexController,
          syncCoordinator: Self.syncCoordinator
        )
      }
    #endif
    #if os(macOS)
      WindowGroup("Presenter", id: "presenter") {
        macOSPresenterView(
          slideSize: Self.configuration.size,
          slideIndexController: Self.configuration.slideIndexController
        ) {
          SlideRouterView(slideIndexController: Self.configuration.slideIndexController)
            .background(theme.backgroundColor)
            // Presenter 用に大きくした font 環境がスライド本体に漏れないようリセット
            .font(nil)
        }
        // macOSPresenterView の原稿 Text はフォント未指定で環境の font を継承するので、
        // ここで上書きして Presenter の原稿を読みやすい大きさにする。
        .font(.system(size: Self.presenterScriptFontSize))
        .environment(\.presentationSyncCoordinator, Self.syncCoordinator)
        .environment(\.slideAudioEnabled, false)
        .preferredColorScheme(.light)
      }
    #endif
  }
}
