import MarkdownToSlide
import SwiftUI

/// 同じ被写体を f値 だけ変えて撮った実写を、開放→絞り込み→開放と往復で自動再生する。
/// コマ間はクロスフェードせず切り替える。混ぜると隣り合う f値 のボケの差が
/// 溶けて読み取れなくなるため、パラパラ漫画のように差分を見せる方を優先する。
///
/// 素材は撮影後に「被写体（カップ）基準の位置合わせ」と「露出の正規化」を済ませてある
/// （`ApertureSamples/`）。手持ちのブレと露出差が残っていると、そちらが動いて見えて
/// 肝心のボケの変化が読み取れないため。背景の椅子だけ僅かにずれるのは視差で、これは実写の事実。
struct ApertureSequenceView: View {
  @Environment(\.slideTheme) var slideTheme

  /// 1コマあたりの表示時間。15枚の往復で片道およそ7秒。
  private static let frameDuration: Duration = .milliseconds(460)

  private let samples = ApertureSampleAssets.samples

  @State private var images: [CGImage] = []
  @State private var index: Int = 0
  /// 往復再生の向き。末尾・先頭で反転する。
  @State private var isStoppingDown = true

  private var currentSample: ApertureSampleAssets.Sample { samples[index] }

  var body: some View {
    HStack(alignment: .center, spacing: 48) {
      photo
      scale
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task {
      // 毎コマ読み直すとデコードで引っかかるので、最初に全コマ展開して持っておく。
      if images.isEmpty {
        images = await Task.detached(priority: .userInitiated) {
          ApertureSampleAssets.loadImages()
        }.value
      }
      guard images.count == samples.count else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.frameDuration)
        if Task.isCancelled { return }
        advance()
      }
    }
  }

  private func advance() {
    if isStoppingDown {
      if index == samples.count - 1 {
        isStoppingDown = false
        index -= 1
      } else {
        index += 1
      }
    } else {
      if index == 0 {
        isStoppingDown = true
        index += 1
      } else {
        index -= 1
      }
    }
  }

  @ViewBuilder
  private var photo: some View {
    ZStack {
      if images.indices.contains(index) {
        Image(decorative: images[index], scale: 1)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        ProgressView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var scale: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(currentSample.label)
        .font(.system(size: 96, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(slideTheme.accentColor)

      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(samples.enumerated()), id: \.element.id) { offset, sample in
          scaleRow(sample: sample, isCurrent: offset == index)
        }
      }

      Text("開放（f値 小）ほど背景がボケ、絞り込むほど奥までシャープになる")
        .font(.system(size: 24))
        .foregroundStyle(slideTheme.secondaryTextColor)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(width: 420, alignment: .leading)
  }

  private func scaleRow(sample: ApertureSampleAssets.Sample, isCurrent: Bool) -> some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 2)
        .fill(isCurrent ? slideTheme.accentColor : slideTheme.secondaryTextColor.opacity(0.3))
        .frame(width: isCurrent ? 40 : 20, height: 4)
      Text(sample.label)
        .font(.system(size: 24, weight: isCurrent ? .semibold : .regular))
        .monospacedDigit()
        .foregroundStyle(isCurrent ? slideTheme.primaryTextColor : slideTheme.secondaryTextColor)
      Spacer(minLength: 0)
    }
    .opacity(isCurrent ? 1 : 0.55)
  }
}

#Preview {
  ApertureSequenceView()
    .padding(60)
    .frame(width: 1280, height: 720)
}
