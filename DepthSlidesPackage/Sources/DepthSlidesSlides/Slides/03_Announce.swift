import DinnerChimeKit
import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct AnnounceSlide: View {
  @Environment(\.slideTheme) var slideTheme
  @State private var chimePlayer: ChimePlayer?

  enum SlidePhase: Int, PhasedState {
    case initial
    case second
    case third
  }

  @Phase var phase: SlidePhase

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .center) {
        switch phase {
        case .initial:
          Text("♪")
            .font(slideTheme.headingH1Font)
        case .second:
          Text("⚠️")
            .font(slideTheme.headingH1Font)
          Text("発表の中で写真を撮影するタイミングがあります。せっかくなのでピースとかしてもらえると嬉しいです✌🏻")
            .font(slideTheme.headingH2Font)
            .multilineTextAlignment(.center)
        case .third:
          Text("♪")
            .font(slideTheme.headingH1Font)
        }
      }
    }
    .padding(slideTheme.contentPadding)
    .onAppear {
      playAnnounce()
    }
    .onChange(of: phase) { oldValue, newValue in
      switch newValue {
      case .initial:
        playChime(.ascending4)
      case .second:
        break
      case .third:
        playChime(.descending4)
      }
    }
  }

  private func playAnnounce() {
    playChime(.ascending4)
  }

  private func playChime(_ sequence: ChimeSequence) {
    let player = chimePlayer ?? ChimePlayer()
    chimePlayer = player
    player.play(sequence)
  }

  var script: String = ""

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    AnnounceSlide()
  }
}
