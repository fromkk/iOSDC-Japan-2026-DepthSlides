#if canImport(UIKit)
  import Observation

  @Observable @MainActor
  final class AppStore {
    var hasExternalDisplay: Bool = false
    var isMirroring: Bool = false
  }
#endif
