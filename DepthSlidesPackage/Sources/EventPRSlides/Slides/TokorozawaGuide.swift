import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct TokorozawaGuide: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme
  let converter = MarkdownToSlideConverter()

  var body: some View {
    ZStack {
      HStack(alignment: .center, spacing: 32) {
        converter.convertPage(markdown)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        Image(.tokorozawaGuide)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .padding(theme.contentPadding)

      if phase == .second {
        Text("フィードバックしてくれよな！！")
          .font(.system(size: 120, weight: .bold))
          .foregroundStyle(.red)
          .shadow(color: Color.black.opacity(0.3), radius: 20, x: 20, y: 20)
          .rotationEffect(.degrees(20))
          .transition(.push(from: .top))
      }
    }
    .animation(.default, value: phase)
  }

  var markdown: String = """
    ## 所沢って？

    - どこ？
    - 何があるの？
    """

  var script: String {
    switch phase {
    case .initial:
      return """
        ところで、所沢ってどこ？何があるの？と思った方もいるかもしれません。
        そのあたりをまとめたガイドを書いたので、気になる方はぜひ読んでみてください。
        """
    case .second:
      return """
        読んだらぜひフィードバックをお願いします！
        以上です。ご清聴ありがとうございました。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview("initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<TokorozawaGuide.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    TokorozawaGuide()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("second") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<TokorozawaGuide.SlidePhase>(.second)
  }
  let controller = SlideIndexController(container: container) {
    TokorozawaGuide()
  }
  return SlideRouterView(slideIndexController: controller)
}
