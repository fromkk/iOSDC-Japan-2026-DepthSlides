import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct PhotoComparison: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
    case third
  }

  @PhaseWrapper var phase: SlidePhase

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
      case .second, .third:
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
                  Color.black.opacity(0.5)
                }
            }
          }

          if phase == .second {
            Text("どっちがiPhoneで撮影したでしょう？")
              .font(SlideTheme.default.headingH3Font)
          } else {
            Text("正解は←")
              .font(SlideTheme.default.headingH3Font)
          }

        }
      }


    }
  }

  var script: String = """
    早速質問です。
    どっちがiPhoneで撮影したでしょうか？
    正解は左側です。
    普段写真を撮っていて「なんかパッとしないな」「もっとよく撮れるはずなんだけどな」と思うことはないでしょうか？
    それは腕が悪いのか、iPhoneが悪いのか、いいカメラを使えばいいのか、今日はそんな問題を解消できないかと試行錯誤した内容についてお話しします。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
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
