import SwiftUI

public struct AwesomeTransition: Transition {
  public init() {}

  public func body(content: Content, phase: TransitionPhase) -> some View {
    content
      .opacity(phase.isIdentity ? 1 : 0)
      .blur(radius: phase.isIdentity ? 0 : 200)
  }
}

extension AnyTransition {
  // アニメーションはここでアタッチしない。アタッチすると暗黙アニメーションが
  // スライドコンテンツ全体に及び、phase 変更まで transition 付きで動いてしまう。
  // SlideKit の `SlideIndexController.forward()` はスライドを進める時だけ
  // `withAnimation` で index を更新するため、これで「進む時だけ」動く。
  public static var awesome: AnyTransition {
    AnyTransition(AwesomeTransition())
  }
}
