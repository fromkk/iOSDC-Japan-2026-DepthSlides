import MarkdownToSlide
import SlideKit
import SwiftUI

/// 被写界深度のシミュレーション → 実写での確認（フェーズ切り替え）。
@Slide
struct FNumberDemo: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case realPhotos
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var slideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("被写界深度")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      Text(
        phase == .initial
          ? "絞りを開ける（f値 小）ほど、ピントが合う範囲＝緑の帯が狭くなる"
          : "同じ被写体を f値 だけ変えて撮ると、ボケはこう変わる"
      )
      .font(slideTheme.headingH3Font)
      .foregroundStyle(slideTheme.accentColor)

      switch phase {
      case .initial:
        DepthOfFieldSlideView()
      case .realPhotos:
        ApertureSequenceView()
      }
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        実際に見てみましょう。黄色い光線とオレンジの点が、ピントを合わせた被写体です。
        緑の帯が被写界深度、つまりこの範囲にある被写体ならシャープに写る、という距離の範囲を表しています。
        f値を小さくして絞りを開けると、この緑の帯が狭くなり被写界深度が浅くなります。逆に f値を大きくして絞りを閉じると、帯が広がって遠くまでピントが合うようになります。
        """
    case .realPhotos:
      return """
        これを実際のカメラで撮った写真で見てみます。
        開放の f1.4 では奥の椅子が大きくボケていますが、絞っていくと奥までピントが合ってくるのが分かると思います。このようにカメラの f値はレンズからの光の量を物理的に調整しています。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    FNumberDemo()
  }
}
