import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PhotoComparison: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
    case third
    case forth
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme

  var body: some View {
    Group {
      switch phase {
      case .initial:
        HStack {
          Spacer()
          Text("Question ?")
            .font(SlideTheme.default.headingH1Font)
          Spacer()
        }
      case .second, .third, .forth:
        VStack {
          HStack {
            VStack {
              Image(.photoIphone)
                .resizable()
                .aspectRatio(contentMode: .fit)
            }

            VStack {
              Image(.photoLeica)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                  if phase == .third {
                    Color.black.opacity(0.5)
                  }
                }
            }
          }

          if phase == .second {
            Text("どっちがiPhoneで撮影したでしょう？")
              .font(SlideTheme.default.headingH3Font)
          } else if phase == .third {
            Text("正解は←")
              .font(SlideTheme.default.headingH3Font)
          }
        }
      }
    }
    .padding(theme.contentPadding)
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        早速質問です。

        """
    case .second:
      return """
        どっちがiPhoneで撮影したでしょうか？
        """
    case .third:
      return """
        正解は左側です。
        """
    case .forth:
      return """
        同じように撮った写真なのに何が違うのでしょうか？
        この場合は色も違いますが、それよりも背景のボケの大きさ・滑らかさが際立つ気がします。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview(".initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<PhotoComparison.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    PhotoComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview(".second") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<PhotoComparison.SlidePhase>(.second)
  }
  let controller = SlideIndexController(container: container) {
    PhotoComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview(".third") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<PhotoComparison.SlidePhase>(.third)
  }
  let controller = SlideIndexController(container: container) {
    PhotoComparison()
  }
  return SlideRouterView(slideIndexController: controller)
}
