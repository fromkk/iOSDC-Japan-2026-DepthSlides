import MarkdownToSlide
import SwiftUI

/// 「写真 → 深度を得る → ぼかす → 結果」のパイプライン図。
/// アプローチ紹介スライドと、各セクションの扉スライドで使い回し、
/// `highlighted` で「いま話しているステップ」だけを強調する（現在地の提示）。
struct PipelineDiagramView: View {
  enum Step: Int, CaseIterable, Identifiable {
    case photo
    case depth
    case blur
    case result

    var id: Int { rawValue }

    var title: String {
      switch self {
      case .photo: "写真"
      case .depth: "深度を得る"
      case .blur: "ぼかす"
      case .result: "結果"
      }
    }

    var detail: String {
      switch self {
      case .photo: "iPhone で撮った\n普通の写真"
      case .depth: "AVDepthData\nor ML モデル"
      case .blur: "Core Image の\nブラーフィルター"
      case .result: "ミラーレス級の\nボケ"
      }
    }

    var symbolName: String {
      switch self {
      case .photo: "photo"
      case .depth: "square.3.layers.3d.down.right"
      case .blur: "circle.dotted.and.circle"
      case .result: "sparkles"
      }
    }
  }

  @Environment(\.slideTheme) private var theme

  /// nil なら全ステップを同じ強さで表示する（全体像の提示用）。
  var highlighted: Step?

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Step.allCases) { step in
        stepBox(step)
        if step != .result {
          Image(systemName: "arrow.right")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(theme.secondaryTextColor)
            .padding(.horizontal, 12)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func stepBox(_ step: Step) -> some View {
    let isActive = highlighted == nil || highlighted == step
    return VStack(spacing: 16) {
      Image(systemName: step.symbolName)
        .font(.system(size: 72))
      Text(step.title)
        .font(.system(size: 44, weight: .bold))
      Text(step.detail)
        .font(.system(size: 26))
        .multilineTextAlignment(.center)
        .lineSpacing(4)
    }
    .foregroundStyle(isActive ? theme.primaryTextColor : theme.secondaryTextColor)
    .frame(maxWidth: .infinity)
    .frame(height: 320)
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(isActive && highlighted != nil ? theme.accentColor.opacity(0.25) : theme.tableBackgroundColor)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(
          isActive && highlighted != nil ? theme.accentColor : Color.clear, lineWidth: 6)
    )
    .opacity(isActive ? 1 : 0.45)
  }
}

#Preview {
  VStack(spacing: 40) {
    PipelineDiagramView()
    PipelineDiagramView(highlighted: .depth)
  }
  .padding(60)
  .background(Color.black)
}
