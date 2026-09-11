import MarkdownToSlide
import SlideKit
import SwiftUI

/// 本題の全体像: 写真 → 深度を得る → ぼかす → 結果 のパイプライン。
///
/// 元は「全体像」と「深度を得る」の扉スライドに分かれていたが、同じ
/// `PipelineDiagramView` がほぼそのまま並ぶだけだったので 1 枚にまとめ、
/// フェーズ送りで現在地のハイライトが点く形にした。
@Slide
struct BokehImprovementApproaches: View {
  enum SlidePhase: Int, PhasedState {
    /// パイプライン全体をフラットに見せる
    case initial
    /// 「深度を得る」を現在地として強調する
    case depth
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme

  private var title: String {
    switch phase {
    case .initial: "スマホで撮影した写真をミラーレス級に近づけるためのアプローチ"
    case .depth: "深度を得る"
    }
  }

  private var highlighted: PipelineDiagramView.Step? {
    switch phase {
    case .initial: nil
    case .depth: .depth
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 48) {
      Text(title)
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)

      PipelineDiagramView(highlighted: highlighted)

      // フェーズを送っても図が動かないよう、キャプションは常に場所を確保して
      // 透明度だけ切り替える。
      Text("写真に埋め込まれた深度 → 無ければ ML モデルで推定する")
        .font(theme.headingH3Font)
        .foregroundStyle(theme.secondaryTextColor)
        .frame(maxWidth: .infinity)
        .opacity(phase == .depth ? 1 : 0)
    }
    .padding(theme.contentPadding)
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        ここからが本題です。やることはポートレートモードと同じで、写真から深度を手に入れて、その深度をもとに背景をぼかす、この 2 ステップです。
        深度は、写真に埋め込まれた AVDepthData を使う方法と、配布されている ML モデルで推定する方法を試しました。ぼかす方は Core Image のブラーフィルターを一通り比較しました。
        この順番で見ていきます。
        """
    case .depth:
      return """
        まずは深度をどう手に入れるかです。今回は写真に埋め込まれている値とMLで推定したものを比較します。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    BokehImprovementApproaches()
  }
}
