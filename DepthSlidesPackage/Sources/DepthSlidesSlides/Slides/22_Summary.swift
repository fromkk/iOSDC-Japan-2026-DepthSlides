import MarkdownToSlide
import SlideKit
import SwiftUI

/// まとめ。左に Before/After（暫定結論の組み合わせでその場で生成）、右に結論。
@Slide
struct Summary: View {
  @Environment(\.slideTheme) var theme
  /// PDF 書き出し時に Before/After の生成完了まで待ってもらうための通知先
  @Environment(\.webPageLoadingTracker) private var loadingTracker
  let converter = MarkdownToSlideConverter()

  /// 暫定結論の組み合わせ
  nonisolated static let chosenModel: DepthModel = .depthAnythingV3Small
  nonisolated static let chosenFilter: BokehFilterKind = .gaussianBlur

  @State private var original: CGImage?
  @State private var result: CGImage?
  @State private var statusMessage = "準備中..."
  @State private var zoomState = ImageZoomState.identity
  @State private var revealFraction: CGFloat = 0.5

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("まとめ")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)

      HStack(alignment: .top, spacing: 32) {
        VStack(spacing: 12) {
          if let original, let result {
            BeforeAfterImageCompareView(
              before: original, after: result,
              beforeLabel: "Before (iPhone)", afterLabel: "After",
              zoomState: $zoomState, revealFraction: $revealFraction)
          } else {
            RoundedRectangle(cornerRadius: 12)
              .fill(theme.tableBackgroundColor)
              .overlay {
                VStack(spacing: 16) {
                  ProgressView().controlSize(.large)
                  Text(statusMessage)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
                }
              }
          }
        }
        .frame(width: 620)

        SlideWrapper {
          converter.convertPage(
            """
            - 今回の選択（暫定）
              - 深度: **\(Self.chosenModel.displayName)**
              - ボケ: **\(Self.chosenFilter.displayName)**
            - 理由: 境界がきれい・61MB・Apache-2.0・速い
            - 課題: 髪や細い枝の境界、距離に応じたボケ量の変化
            """
          )
        }
      }
    }
    .padding(theme.contentPadding)
    .task { await process() }
  }

  private func process() async {
    guard result == nil else { return }
    loadingTracker?.startedLoading()
    defer { loadingTracker?.finishedLoading() }
    guard let data = DepthSampleAssets.data(for: .sunflowerIPhone),
      let cgImage = DepthSampleAssets.cgImage(from: data)
    else {
      statusMessage = "DepthSamples/IMG_2569.jpeg が見つかりません"
      return
    }
    original = cgImage
    guard Self.chosenModel.packageURL != nil else {
      statusMessage = "\(Self.chosenModel.displayName) のモデルが見つかりません（scripts/ を実行してください）"
      return
    }
    do {
      statusMessage = "\(Self.chosenModel.displayName) で深度を推定中..."
      let depth = try await DepthEstimator.shared.estimateCached(
        cgImage: cgImage, model: Self.chosenModel,
        cacheKey: DepthCacheKey(imageData: data, model: Self.chosenModel)
      ) { phase in
        switch phase {
        case .compilingModel: statusMessage = "モデルをコンパイル中...（初回のみ）"
        case .loadingModel: statusMessage = "モデルを読み込み中..."
        case .inferring: statusMessage = "深度を推定中..."
        }
      }
      statusMessage = "\(Self.chosenFilter.displayName) を適用中..."
      let blurred = await Task.detached(priority: .userInitiated) {
        CIFilterBokehBlur.apply(
          original: cgImage, depth: depth, filter: Self.chosenFilter,
          parameters: BokehFilterParameters())
      }.value
      result = blurred
      if blurred == nil { statusMessage = "ボケの適用に失敗しました" }
    } catch {
      statusMessage = "深度推定に失敗しました: \(error)"
    }
  }

  var script: String = """
    まとめです。左が iPhone で撮ったそのままの写真、仕切りを動かすと \(Self.chosenModel.displayName) で深度を推定して \(Self.chosenFilter.displayName) でボカした結果です。
    今回は深度に Depth Anything V3、ボケに CIGaussianBlur を選びました。V3 は Small でも境界がきれいで、61MB・Apache-2.0 なのでアプリに同梱できます。Gaussian は自然で速く、深度マスクとの相性も良かったです。
    一方で、髪の毛や細い枝のような境界の取りこぼしや、本物のレンズのように距離に応じてボケ量が変わる表現はまだできていません。ここは今後の課題です。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    Summary()
  }
}
