import CoreGraphics
import SwiftUI

/// 1枚の画像をピンチズーム・パンしながら、タップした位置を画像上の正規化座標
/// （左上原点・0...1）で通知できる汎用View。`BeforeAfterImageCompareView` の
/// ビフォーアフター比較（見え隠れスライダー）が不要な場面向けのシンプル版。
///
/// ズーム・パン・タップの座標変換ロジックは `BeforeAfterImageCompareView` と
/// 同じ考え方（外側の変形されないコンテナを基準にした named coordinate space +
/// 現在のズーム/パンを自前で逆算）を採用している。詳しくはそちらのコメント参照。
struct ZoomableFocusableImageView: View {
  let image: CGImage
  /// `nil`（デフォルト）だとタップジェスチャー自体を無効化する。
  var onTap: ((CGPoint) -> Void)?
  @Binding var zoomState: ImageZoomState

  @GestureState private var magnifyDelta: CGFloat = 1
  @GestureState private var panDelta: CGSize = .zero
  @State private var tapIndicatorLocation: CGPoint?

  private let minScale: CGFloat = 1
  private let maxScale: CGFloat = 6
  private let zoomStep: CGFloat = 1.5

  private static let coordinateSpaceName = "ZoomableFocusableImageView.container"

  var body: some View {
    GeometryReader { geo in
      ZStack {
        Image(decorative: image, scale: 1)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: geo.size.width, height: geo.size.height)
          .clipped()
          .contentShape(Rectangle())
          .scaleEffect(currentScale)
          .offset(currentOffset)
          .gesture(panGesture)
          .simultaneousGesture(magnifyGesture)
          .simultaneousGesture(tapGesture(containerSize: geo.size))

        if let tapIndicatorLocation {
          focusIndicator
            .position(tapIndicatorLocation)
            .allowsHitTesting(false)
        }

        zoomButtons
          .padding(12)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
      .coordinateSpace(name: Self.coordinateSpaceName)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var zoomButtons: some View {
    VStack(spacing: 8) {
      Button {
        zoomState.scale = min(maxScale, zoomState.scale * zoomStep)
      } label: {
        Image(systemName: "plus.magnifyingglass")
      }
      Button {
        zoomState.scale = max(minScale, zoomState.scale / zoomStep)
        if zoomState.scale <= minScale {
          zoomState.offset = .zero
        }
      } label: {
        Image(systemName: "minus.magnifyingglass")
      }
    }
    .font(.system(size: 18, weight: .semibold))
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.circle)
  }

  private var focusIndicator: some View {
    Circle()
      .stroke(.yellow, lineWidth: 2)
      .frame(width: 64, height: 64)
      .overlay {
        Circle()
          .stroke(.yellow, lineWidth: 1)
          .frame(width: 16, height: 16)
      }
      .shadow(radius: 2)
  }

  // MARK: - ジェスチャー

  private var currentScale: CGFloat {
    min(maxScale, max(minScale, zoomState.scale * magnifyDelta))
  }

  private var currentOffset: CGSize {
    CGSize(
      width: zoomState.offset.width + panDelta.width,
      height: zoomState.offset.height + panDelta.height)
  }

  private var magnifyGesture: some Gesture {
    MagnifyGesture()
      .updating($magnifyDelta) { value, state, _ in
        state = value.magnification
      }
      .onEnded { value in
        zoomState.scale = min(maxScale, max(minScale, zoomState.scale * value.magnification))
      }
  }

  private var panGesture: some Gesture {
    DragGesture()
      .updating($panDelta) { value, state, _ in
        state = value.translation
      }
      .onEnded { value in
        zoomState.offset.width += value.translation.width
        zoomState.offset.height += value.translation.height
      }
  }

  /// `.named(Self.coordinateSpaceName)` を使うことで、`value.location` は
  /// ズーム・パンされている画像自身の `.local` 座標系ではなく、変形の影響を
  /// 受けないコンテナ基準の座標として得られる。そこから現在のズーム・パンを
  /// 自前で打ち消して、実際に見えている画像内容のどの位置がタップされたかを求める。
  private func tapGesture(containerSize: CGSize) -> some Gesture {
    SpatialTapGesture(coordinateSpace: .named(Self.coordinateSpaceName))
      .onEnded { value in
        guard let onTap else { return }
        tapIndicatorLocation = value.location
        let unscaledPoint = unscaledLocalPoint(from: value.location, containerSize: containerSize)
        let normalized = normalizedImagePoint(from: unscaledPoint, containerSize: containerSize)
        onTap(normalized)
      }
  }

  /// コンテナ基準のタップ位置から、現在のズーム倍率・パンオフセットを打ち消して
  /// 「等倍・パン無し」のローカル座標（containerSize 基準）に変換する。
  private func unscaledLocalPoint(from containerPoint: CGPoint, containerSize: CGSize) -> CGPoint {
    let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
    let afterOffset = CGPoint(
      x: containerPoint.x - currentOffset.width, y: containerPoint.y - currentOffset.height)
    let relativeToCenter = CGPoint(x: afterOffset.x - center.x, y: afterOffset.y - center.y)
    let unscaled = CGPoint(
      x: relativeToCenter.x / currentScale, y: relativeToCenter.y / currentScale)
    return CGPoint(x: unscaled.x + center.x, y: unscaled.y + center.y)
  }

  /// コンテナ内でのタップ位置（ズーム・パン無しの `geo.size` 基準ローカル座標）を、
  /// `image` の正規化座標（左上原点・0...1）に変換する。画像は `.aspectRatio(.fit)`
  /// でコンテナ内に収まるように描画されており、コンテナとアスペクト比が異なる場合は
  /// 左右または上下に余白（レターボックス）が生まれるため、fit 表示時の実際の
  /// 縮小率・余白量を考慮する。
  private func normalizedImagePoint(from location: CGPoint, containerSize: CGSize) -> CGPoint {
    let imageSize = CGSize(width: image.width, height: image.height)
    guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0,
      containerSize.height > 0
    else { return CGPoint(x: 0.5, y: 0.5) }

    let fitScale = min(
      containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    let renderedSize = CGSize(
      width: imageSize.width * fitScale, height: imageSize.height * fitScale)
    let letterboxX = (containerSize.width - renderedSize.width) / 2
    let letterboxY = (containerSize.height - renderedSize.height) / 2

    let pixelX = (location.x - letterboxX) / fitScale
    let pixelY = (location.y - letterboxY) / fitScale

    return CGPoint(
      x: min(max(pixelX / imageSize.width, 0), 1),
      y: min(max(pixelY / imageSize.height, 0), 1))
  }
}

#Preview {
  @Previewable @State var zoomState = ImageZoomState.identity

  let width = 400
  let height = 300
  guard
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { fatalError() }
  context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  let image = context.makeImage()!

  return ZoomableFocusableImageView(image: image, zoomState: $zoomState)
    .frame(width: 500, height: 375)
    .padding()
}
