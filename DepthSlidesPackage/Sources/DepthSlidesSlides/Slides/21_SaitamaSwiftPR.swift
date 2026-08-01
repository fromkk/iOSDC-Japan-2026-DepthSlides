import AVKit
import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct SaitamaSwiftPR: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
    case third
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme

  let videoURL: URL? = Bundle.module.url(forResource: "saitama_swift_cm", withExtension: "mp4")

  var body: some View {
    switch phase {
    case .initial:
      if let videoURL {
        VideoPlayer(player: AVPlayer(url: videoURL))
      }
    case .second:
      VStack {
        HStack {
          Image(.saitamaSwift)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          Image(.saitamaSwiftQr)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
        }
        Text("https://japan-region-swift.connpass.com/event/397259/")
      }
      .padding(theme.contentPadding)
    case .third:
      VStack {
        HStack {
          Image(.saitamaSwiftAfterparty)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          Image(.saitamaSwiftAfterpartyQr)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
        }
        Text("https://japan-region-swift.connpass.com/event/397260/")
      }
      .padding(theme.contentPadding)
    }
  }

  var script: String = """
    最後に宣伝です。11月21日土曜日に、埼玉県初の Japan-\\(region).swift、Saitama.swift をやります。
    会場は所沢市民文化センター ミューズです。
    懇親会はぎょうざの満洲でやります。少し早い忘年会として、人生トークなどもしつつ、一緒に餃子を食べましょう。
    以上です。ご清聴ありがとうございました。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview("initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<SaitamaSwiftPR.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    SaitamaSwiftPR()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("second") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<SaitamaSwiftPR.SlidePhase>(.second)
  }
  let controller = SlideIndexController(container: container) {
    SaitamaSwiftPR()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview("third") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<SaitamaSwiftPR.SlidePhase>(.third)
  }
  let controller = SlideIndexController(container: container) {
    SaitamaSwiftPR()
  }
  return SlideRouterView(slideIndexController: controller)
}
