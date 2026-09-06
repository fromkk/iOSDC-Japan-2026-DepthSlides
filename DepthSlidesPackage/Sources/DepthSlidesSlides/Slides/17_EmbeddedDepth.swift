import MarkdownToSlide
import SlideKit
import SwiftUI

/// アプローチ①: 写真に埋め込まれた AVDepthData を取得して可視化する。
/// 左にコード、右に実際のポートレート写真から取り出した深度マップを表示する。
@Slide
struct EmbeddedDepth: View {
  @Environment(\.slideTheme) var theme
  @Environment(\.webPageLoadingTracker) private var loadingTracker
  @State private var original: CGImage?
  @State private var depth: CGImage?
  @State private var errorMessage: String?
  @State private var zoomState = ImageZoomState.identity
  @State private var revealFraction: CGFloat = 0.5

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      SlideHeader(.embeddedDepth)

      Text("写真に埋め込まれた深度情報を取得")
        .font(theme.headingH2Font)
        .foregroundStyle(theme.primaryTextColor)

      HStack(alignment: .top, spacing: 32) {
        // Markdown のコードブロックだとフォントが大きく折り返されて読めないため、
        // 等幅の Text で固定サイズにして表示する
        Text(Self.codeSample)
          .font(.system(size: 30, design: .monospaced))
          .foregroundStyle(theme.primaryTextColor)
          .lineSpacing(6)
          .padding(24)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .background(
            RoundedRectangle(cornerRadius: 12).fill(theme.tableBackgroundColor))

        VStack(spacing: 12) {
          if let original, let depth {
            BeforeAfterImageCompareView(
              before: original, after: depth,
              beforeLabel: "元画像", afterLabel: "AVDepthData",
              zoomState: $zoomState, revealFraction: $revealFraction)
          } else {
            RoundedRectangle(cornerRadius: 12)
              .fill(theme.tableBackgroundColor)
              .overlay {
                Text(errorMessage ?? "読み込み中...")
                  .font(theme.bodyFont)
                  .foregroundStyle(theme.secondaryTextColor)
              }
          }
        }
        .frame(width: 520)
      }
    }
    .padding(theme.contentPadding)
    .task { await load() }
  }

  private func load() async {
    guard original == nil else { return }
    loadingTracker?.startedLoading()
    defer { loadingTracker?.finishedLoading() }
    guard let data = DepthSampleAssets.data(for: .portraitWithDepth) else {
      errorMessage = "DepthSamples/IMG_1606.heic が見つかりません"
      return
    }
    original = DepthSampleAssets.cgImage(from: data)
    do {
      depth = try EmbeddedDepthExtractor.extractDepthImage(from: data)
    } catch {
      errorMessage = "深度の取得に失敗: \(error)"
    }
  }

  /// `DepthModel.embeddedDepth.estimationCodeSample` を要点だけに短縮したもの
  static let codeSample = """
    // HEIC の補助データから AVDepthData を取り出す
    let source = CGImageSourceCreateWithData(data, nil)!
    let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
      source, 0, kCGImageAuxiliaryDataTypeDisparity
    ) as! [AnyHashable: Any]
    let depth = try AVDepthData(
      fromDictionaryRepresentation: info
    )

    // 視差 (近い = 明るい) に統一して CIImage にする
    let disparity = depth.converting(
      toDepthDataType: kCVPixelFormatType_DisparityFloat32
    )
    let image = CIImage(cvPixelBuffer: disparity.depthDataMap)
    """

  var script: String = """
    まずは写真に埋め込まれた深度情報を取得してみます。ポートレートモードで撮った HEIC には AVDepthData が補助データとして埋め込まれていることがあり、ImageIO 経由でこのように取り出せます。
    右の写真の仕切りを動かすと、実際に取り出した深度マップが見えます。明るいほど手前です。
    ただしこれはiPhoneのポートレートモードで撮った写真かオブジェクトと背景がいい感じに分離されている写真にしか入っていません。普通に撮った写真や、他社のカメラの写真には深度がないので、そこで ML モデルの出番になります。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    EmbeddedDepth()
  }
}
