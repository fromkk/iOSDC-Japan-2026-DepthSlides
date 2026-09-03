import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct AboutLens: View {
  @Environment(\.slideTheme) var theme
  let converter = MarkdownToSlideConverter()

  enum SlidePhase: Int, PhasedState {
    case initial
    case second
  }

  @Phase var phase: SlidePhase

  var body: some View {
    HStack {
      SlideWrapper {
        converter.convertPage(markdown)
      }

      VStack {
        switch phase {
        case .initial:
          Image(.bunbouguMushimegane)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 600)

          Text("https://www.irasutoya.com/2013/03/blog-post_385.html")
            .font(theme.bodyFont)
        case .second:
          Image(.sigmaLens)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 600)

          Text("https://www.sigma-global.com/jp/lenses/c021_28_70_28/?tab=construction")
            .font(theme.bodyFont)
        }
      }
      .padding(theme.contentPadding)
    }
  }

  var markdown: String {
    var markdown = """
      ## レンズ

      - 針の穴だけのカメラ・オブスキュラは光量が少なくて暗い
      - 光を集めるためにレンズが使われるように
      - 虫眼鏡のような凸レンズが一般的
      """

    if phase == .second {
      markdown.append("""
        
          - 現代では様々なレンズを組み合わせてできている
        """)
    }

    return markdown
  }

  var script: String {
    """
    針の穴だけのカメラ・オブスキュラでは光量が少なくて暗いという問題がありました。
    これを解決するためにレンズが利用されるようになりました。
    当初は虫眼鏡のような凸れんずを利用することが一般的でした。
    現代では凸レンズ、凹レンズなど様々なレンズを組み合わせてできています。
    こちらはとあるSIGMAのレンズ構成図です。
    様々な形のレンズが複雑に組み合わさってできていることがわかります。
    """
  }
}

#Preview(".initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<AboutLens.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    AboutLens()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview(".second") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<AboutLens.SlidePhase>(.second)
  }
  let controller = SlideIndexController(container: container) {
    AboutLens()
  }
  return SlideRouterView(slideIndexController: controller)
}
