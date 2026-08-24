#if canImport(UIKit)
  import DepthSlidesSlides
  import OSLog
  import UIKit

  @main
  class AppDelegate: UIResponder, UIApplicationDelegate {
    private let logger = Logger(
      subsystem: Bundle.main.bundleIdentifier!,
      category: "AppDelegate"
    )

    let configuration = SlideConfiguration()
    let store = AppStore()
    let syncCoordinator = PresentationSyncCoordinator()

    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      logger.info("\(#function)")
      // 登壇中にスライドを表示したまま放置しても画面が自動ロックされないようにする
      application.isIdleTimerDisabled = true
      syncCoordinator.start(attachingTo: configuration.slideIndexController)
      return true
    }

    func application(
      _ application: UIApplication,
      configurationForConnecting connectingSceneSession: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
      logger.info("\(#function)")
      if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
        return UISceneConfiguration(
          name: "External Configuration",
          sessionRole: connectingSceneSession.role
        )
      } else {
        return UISceneConfiguration(
          name: "Default Configuration",
          sessionRole: connectingSceneSession.role
        )
      }
    }

    func application(
      _ application: UIApplication,
      didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
      logger.info("\(#function)")
    }
  }
#endif
