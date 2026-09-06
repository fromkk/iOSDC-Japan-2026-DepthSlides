import MarkdownToSlide
import SwiftUI

/// 同じ場所から iPhone のレンズ倍率だけを変えて撮った実写を、広角→望遠の
/// 一方向で繰り返し自動再生する（望遠の後は広角へ戻って再スタート）。`ApertureSequenceView` と同じく、コマ間はクロスフェードせず
/// 切り替える。混ぜると隣り合う倍率のボケの差が溶けて読み取れなくなるため。
///
/// 倍率が上がると画角が狭まって構図そのものが変わるので、f値 の連番より
/// 1コマを長めに見せる。
struct TelephotoSequenceView: View {
  @Environment(\.slideTheme) var slideTheme

  /// 1コマあたりの表示時間。4枚で1周およそ5.6秒。
  private static let frameDuration: Duration = .milliseconds(1400)

  private let samples = TelephotoSampleAssets.samples

  @State private var images: [CGImage] = []
  @State private var index: Int = 0

  private var currentSample: TelephotoSampleAssets.Sample { samples[index] }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      photo
      caption
    }
    .task {
      // 毎コマ読み直すとデコードで引っかかるので、最初に全コマ展開して持っておく。
      if images.isEmpty {
        images = await Task.detached(priority: .userInitiated) {
          TelephotoSampleAssets.loadImages()
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
    index = (index + 1) % samples.count
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
    .overlay {
      Rectangle()
        .strokeBorder(slideTheme.primaryTextColor.opacity(0.24), lineWidth: 2)
    }
  }

  /// 現在の倍率と、全コマ分の目盛り。スライド本体がモノクロなので色は足さない。
  private var caption: some View {
    HStack(alignment: .firstTextBaseline, spacing: 28) {
      Text(currentSample.zoomLabel)
        .font(.system(size: 56, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(slideTheme.primaryTextColor)
        .frame(width: 96, alignment: .leading)

      Text(currentSample.focalLengthLabel)
        .font(.system(size: 30))
        .monospacedDigit()
        .foregroundStyle(slideTheme.secondaryTextColor)

      Spacer(minLength: 0)

      HStack(spacing: 14) {
        ForEach(Array(samples.enumerated()), id: \.element.id) { offset, sample in
          scaleTick(sample: sample, isCurrent: offset == index)
        }
      }
    }
  }

  private func scaleTick(sample: TelephotoSampleAssets.Sample, isCurrent: Bool) -> some View {
    VStack(spacing: 8) {
      Text(sample.zoomLabel)
        .font(.system(size: 22, weight: isCurrent ? .semibold : .regular))
        .monospacedDigit()
        .foregroundStyle(isCurrent ? slideTheme.primaryTextColor : slideTheme.secondaryTextColor)
      Rectangle()
        .fill(isCurrent ? slideTheme.primaryTextColor : slideTheme.secondaryTextColor.opacity(0.3))
        .frame(width: 48, height: isCurrent ? 4 : 2)
    }
    .opacity(isCurrent ? 1 : 0.6)
  }
}

#Preview {
  TelephotoSequenceView()
    .padding(60)
    .frame(width: 800, height: 1080)
}
