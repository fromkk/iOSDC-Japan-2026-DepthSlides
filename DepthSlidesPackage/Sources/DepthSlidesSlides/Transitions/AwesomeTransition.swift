import SwiftUI

struct AwesomeTransition: Transition {
  func body(content: Content, phase: TransitionPhase) -> some View {
    content
      .scaleEffect(phase.isIdentity ? 1 : 1.5)
      .opacity(phase.isIdentity ? 1 : 0)
      .blur(radius: phase.isIdentity ? 0 : 100)
  }
}
