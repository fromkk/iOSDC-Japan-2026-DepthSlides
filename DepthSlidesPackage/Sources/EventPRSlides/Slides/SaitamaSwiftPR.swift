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
  @Environment(\.slideAudioEnabled) var slideAudioEnabled

  let videoURL: URL? = Bundle.module.url(
    forResource: "saitama_swift_cm",
    withExtension: "mp4"
  )

  var body: some View {
    switch phase {
    case .initial:
      if let videoURL {
        VideoPlayer(player: makePlayer(url: videoURL))
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
          .font(theme.bodyFont)
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
          .font(theme.bodyFont)
      }
      .padding(theme.contentPadding)
    }
  }

  private func makePlayer(url: URL) -> AVPlayer {
    let player = AVPlayer(url: url)
    player.isMuted = !slideAudioEnabled
    return player
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        そしてもう一つ、11月21日土曜日に、埼玉県初の Japan-\\(region).swift、Saitama.swift をやります。
        """
    case .second:
      return "会場は所沢市民文化センター ミューズです。"
    case .third:
      return """
        懇親会はぎょうざの満洲でやります。少し早い忘年会として、人生トークなどもしつつ、一緒に餃子を食べましょう。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
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
