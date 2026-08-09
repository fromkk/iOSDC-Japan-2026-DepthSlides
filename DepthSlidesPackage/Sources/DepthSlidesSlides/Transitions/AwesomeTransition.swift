import SwiftUI

struct AwesomeTransition: Transition {
  func body(content: Content, phase: TransitionPhase) -> some View {
    content
      .opacity(phase.isIdentity ? 1 : 0)
      .blur(radius: phase.isIdentity ? 0 : 200)
  }
}

extension AnyTransition {
  static var awesome: AnyTransition {
    AnyTransition(AwesomeTransition()).animation(.easeInOut(duration: 0.6))
  }
}
