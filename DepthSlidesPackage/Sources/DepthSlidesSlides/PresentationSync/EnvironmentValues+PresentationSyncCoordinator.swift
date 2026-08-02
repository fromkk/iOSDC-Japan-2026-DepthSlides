import SwiftUI

private struct PresentationSyncCoordinatorKey: EnvironmentKey {
  static let defaultValue: PresentationSyncCoordinator? = nil
}

extension EnvironmentValues {
  public var presentationSyncCoordinator: PresentationSyncCoordinator? {
    get { self[PresentationSyncCoordinatorKey.self] }
    set { self[PresentationSyncCoordinatorKey.self] = newValue }
  }
}
