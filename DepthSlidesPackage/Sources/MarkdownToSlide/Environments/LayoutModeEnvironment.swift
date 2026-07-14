import SwiftUI

// Environment key for layout mode
private struct LayoutModeKey: EnvironmentKey, Sendable {
  static let defaultValue: PageLayoutMode = .standard
}

extension EnvironmentValues {
  var layoutMode: PageLayoutMode {
    get { self[LayoutModeKey.self] }
    set { self[LayoutModeKey.self] = newValue }
  }
}
