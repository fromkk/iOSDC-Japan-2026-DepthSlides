import MarkdownToSlide
import SlideKit
import SwiftUI

/// 被写界深度のシミュレーション → 実機カメラでの実演（フェーズ切り替え）。
@Slide
struct FNumberDemo: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case liveCamera
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var slideTheme

  @State private var uvcSession = UVCCameraSession()

  private var isShowingPreview: Bool { uvcSession.selectedSource != nil }

  private var sourceSelection: Binding<UVCCameraSession.Source?> {
    Binding(
      get: { uvcSession.selectedSource },
      set: { uvcSession.select($0) }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("被写界深度")
        .font(slideTheme.headingH1Font)
        .foregroundStyle(slideTheme.primaryTextColor)

      Text(
        phase == .initial
          ? "絞りを開ける（f値 小）ほど、ピントが合う範囲＝緑の帯が狭くなる"
          : "実際のカメラで、絞りを変えるとボケがどう変わるか"
      )
      .font(slideTheme.headingH3Font)
      .foregroundStyle(slideTheme.accentColor)

      switch phase {
      case .initial:
        DepthOfFieldSlideView()
      case .liveCamera:
        liveCameraView
      }
    }
    .padding(slideTheme.contentPadding)
    .background(slideTheme.backgroundColor)
    .onAppear { uvcSession.startMonitoring() }
    .onDisappear { uvcSession.stopMonitoring() }
  }

  private var liveCameraView: some View {
    VStack(spacing: 16) {
      // 切り替えのたびにUVCCameraPreviewViewをツリーから外し／戻すと、その都度
      // AVCaptureVideoPreviewLayerが生成し直され、まれに何も映らない状態になるため、
      // Viewはツリーに残したまま見た目だけをopacity/frameで切り替える。
      UVCCameraPreviewView(session: uvcSession)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isShowingPreview ? 1 : 0)
        .overlay {
          if !isShowingPreview {
            Text(
              uvcSession.availableSources.isEmpty
                ? "カメラが見つかりません" : "下のピッカーでカメラを選んでください"
            )
            .font(slideTheme.bodyFont)
            .foregroundStyle(slideTheme.secondaryTextColor)
          }
        }

      Picker("カメラ", selection: sourceSelection) {
        Text("非表示").tag(UVCCameraSession.Source?.none)
        if uvcSession.availableSources.contains(.builtIn) {
          Text("内蔵カメラ").tag(UVCCameraSession.Source?.some(.builtIn))
        }
        if uvcSession.availableSources.contains(.external) {
          Text("UVC").tag(UVCCameraSession.Source?.some(.external))
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
    }
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        実際に見てみましょう。黄色い光線とオレンジの点が、ピントを合わせた被写体です。
        緑の帯が被写界深度、つまりこの範囲にある被写体ならシャープに写る、という距離の範囲を表しています。
        f値を小さくして絞りを開けると、この緑の帯が狭くなり被写界深度が浅くなります。逆に f値を大きくして絞りを閉じると、帯が広がって遠くまでピントが合うようになります。
        """
    case .liveCamera:
      return """
        ここで実際のカメラを使って実演してみます。手前のものにピントを合わせて絞りを開けると、奥はボケます。
        絞りを小さく、f値を大きくしていくと、奥までピントが合ってくるのが分かると思います。このようにカメラの f値はレンズからの光の量を物理的に調整しています。
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
