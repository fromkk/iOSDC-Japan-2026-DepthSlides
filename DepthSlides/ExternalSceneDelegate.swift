#if canImport(UIKit)
  import DepthSlidesSlides
  import SlideKit
  import SwiftUI
  import UIKit

  final class ExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
      _ scene: UIScene,
      willConnectTo session: UISceneSession,
      options connectionOptions: UIScene.ConnectionOptions
    ) {
      guard
        let windowScene = scene as? UIWindowScene,
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
      else {
        return
      }

      appDelegate.store.hasExternalDisplay = true
      createWindow(windowScene, configuration: appDelegate.configuration)
      subscribeStore(windowScene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
      (UIApplication.shared.delegate as? AppDelegate)?.store.hasExternalDisplay = false
    }

    private func subscribeStore(_ scene: UIWindowScene) {
      guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
      let store = appDelegate.store
      withObservationTracking {
        _ = store.isMirroring
      } onChange: { [weak self] in
        Task { @MainActor in
          if store.isMirroring {
            self?.window = nil
          } else {
            self?.createWindow(scene, configuration: appDelegate.configuration)
          }
          self?.subscribeStore(scene)
        }
      }
    }

    private func createWindow(_ scene: UIWindowScene, configuration: SlideConfiguration) {
      let contentView = PresentationView(slideSize: configuration.size) {
        SlideRouterView(slideIndexController: configuration.slideIndexController)
      }
      .preferredColorScheme(.light)
      let window = UIWindow(windowScene: scene)
      window.overrideUserInterfaceStyle = .light
      window.rootViewController = UIHostingController(rootView: contentView)
      window.makeKeyAndVisible()
      self.window = window
    }
  }
#endif
