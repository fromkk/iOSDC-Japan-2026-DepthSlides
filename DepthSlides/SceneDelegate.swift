#if canImport(UIKit)
  import MarkdownToSlide
  import DepthSlidesSlides
  import OSLog
  import SlideKit
  import SwiftUI
  import UIKit

  class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private let logger = Logger(
      subsystem: Bundle.main.bundleIdentifier!,
      category: "AppDelegate"
    )

    let theme: MarkdownToSlide.SlideTheme = .default
    var window: UIWindow?

    func scene(
      _ scene: UIScene,
      willConnectTo session: UISceneSession,
      options connectionOptions: UIScene.ConnectionOptions
    ) {
      logger.info("\(#function)")
      guard
        let windowScene = scene as? UIWindowScene,
        let configuration = (UIApplication.shared.delegate as? AppDelegate)?
          .configuration
      else {
        return
      }

      let store = (UIApplication.shared.delegate as? AppDelegate)?.store

      window = UIWindow(windowScene: windowScene)
      window?.overrideUserInterfaceStyle = .light
      window?.rootViewController = UIHostingController(
        rootView: SlideNavigationView(configuration: configuration, store: store)
          .slideTheme(theme)
          .preferredColorScheme(.light)
      )
      window?.makeKeyAndVisible()
    }
  }
#endif
