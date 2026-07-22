import CoreGraphics
import SwiftUI

/// 2枚の画像（`before`/`after`）をピンチズーム・パンしながら、ドラッグ可能な
/// 縦の仕切り線で見え隠れさせて比較できる汎用View。
///
/// `zoomState`/`revealFraction` は呼び出し側が保持する `@Binding` にすることで、
/// 「新しい画像を選んだときだけリセットし、モデルの切り替え時は同じズーム・
/// 比較位置を保つ」という挙動を呼び出し側で制御できるようにしている。
///
/// ジェスチャー設計: 仕切り用のハンドルは `before`/`after`/マスクと同じ
/// `.scaleEffect`/`.offset` チェーンの**外側**（ZStackの兄弟要素）に置く。
/// これにより、ハンドル上で始まったドラッグは常にハンドル専用の
/// `DragGesture` が受け取り、それ以外の領域のドラッグはパン用の
/// `DragGesture` が受け取る（SwiftUI はジェスチャーがアタッチされた
/// サブビューの領域内でのみそのジェスチャーを発火させるため、明示的な
/// 排他制御なしに競合を避けられる）。
struct BeforeAfterImageCompareView: View {
  let before: CGImage
  let after: CGImage
  var beforeLabel: String = "元画像"
  var afterLabel: String = "深度画像"
  /// タップされた位置を画像に対する正規化座標（左上原点・0...1）で通知する。
  /// `nil`（デフォルト）のままだとタップジェスチャー自体を無効化する
  /// （比較モードなど、タップに意味を持たせない呼び出し元向け）。
  var onTap: ((CGPoint) -> Void)?
  @Binding var zoomState: ImageZoomState
  @Binding var revealFraction: CGFloat

  @GestureState private var magnifyDelta: CGFloat = 1
  @GestureState private var panDelta: CGSize = .zero
  @GestureState private var dividerDragDelta: CGFloat = 0
  @State private var tapIndicatorLocation: CGPoint?

  private let minScale: CGFloat = 1
  private let maxScale: CGFloat = 6
  private let zoomStep: CGFloat = 1.5
  private let handleWidth: CGFloat = 32

  /// タップジェスチャーを `.scaleEffect`/`.offset` されたビュー自身の `.local`
  /// 座標系に頼らず、ズーム・パンの影響を受けない外側コンテナ基準で取得する
  /// ための名前付き座標空間。`.local` がスケール・オフセットをどこまで
  /// 自動的に打ち消してくれるかは自明ではないため、コンテナ基準の座標を
  /// 明示的に取得したうえで、既知の `currentScale`/`currentOffset` を
  /// 自前で逆変換する方針にしている（`normalizedImagePoint` 参照）。
  private static let coordinateSpaceName = "BeforeAfterImageCompareView.container"

  var body: some View {
    GeometryReader { geo in
      let fraction = currentRevealFraction(containerWidth: geo.size.width)

      ZStack {
        imageStack(fraction: fraction, containerSize: geo.size)
          .frame(width: geo.size.width, height: geo.size.height)
          .scaleEffect(currentScale)
          .offset(currentOffset)
          .contentShape(Rectangle())
          .gesture(panGesture)
          .simultaneousGesture(magnifyGesture)
          .simultaneousGesture(tapGesture(containerSize: geo.size))
          .clipped()

        dividerHandle(fraction: fraction, containerSize: geo.size)

        if let tapIndicatorLocation {
          focusIndicator
            .position(tapIndicatorLocation)
            .allowsHitTesting(false)
        }

        labels

        zoomButtons
          .padding(12)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
      .coordinateSpace(name: Self.coordinateSpaceName)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  /// `before`/`after` は常に同じピクセルサイズ（`DepthEstimator` が深度画像を
  /// 元画像と同じ寸法にリサイズして返すため）なので、`.fit` で描画しても両者は
  /// 常に同じ位置・同じ大きさにレターボックスされる。ハンドル・マスクは
  /// （画像フレームではなく）`containerSize` 基準のまま変更していないため、
  /// レターボックスの余白ごと一貫して見え隠れする形になり、ズレは生じない。
  private func imageStack(fraction: CGFloat, containerSize: CGSize) -> some View {
    ZStack {
      Image(decorative: before, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()

      Image(decorative: after, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()
        .mask(alignment: .leading) {
          Rectangle().frame(width: containerSize.width * fraction, height: containerSize.height)
        }
    }
  }

  private var labels: some View {
    VStack {
      HStack {
        label(beforeLabel)
        Spacer()
        label(afterLabel)
      }
      Spacer()
    }
    .padding(12)
    .allowsHitTesting(false)
  }

  private func label(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(.black.opacity(0.5), in: Capsule())
  }

  private func dividerHandle(fraction: CGFloat, containerSize: CGSize) -> some View {
    ZStack {
      Rectangle()
        .fill(.white)
        .frame(width: 3, height: containerSize.height)
      Circle()
        .fill(.white)
        .frame(width: handleWidth, height: handleWidth)
        .shadow(radius: 2)
        .overlay {
          Image(systemName: "arrow.left.and.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.black)
        }
    }
    .frame(width: handleWidth, height: containerSize.height)
    .contentShape(Rectangle())
    .position(x: containerSize.width * fraction, y: containerSize.height / 2)
    .gesture(dividerDragGesture(containerWidth: containerSize.width))
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

  // MARK: - ジェスチャー

  /// 現在表示すべき拡大率。コミット済みの `zoomState.scale` に、進行中の
  /// ピンチ操作分の倍率 (`magnifyDelta`) を掛け合わせてクランプする。
  private var currentScale: CGFloat {
    min(maxScale, max(minScale, zoomState.scale * magnifyDelta))
  }

  private var currentOffset: CGSize {
    CGSize(
      width: zoomState.offset.width + panDelta.width,
      height: zoomState.offset.height + panDelta.height)
  }

  private func currentRevealFraction(containerWidth: CGFloat) -> CGFloat {
    guard containerWidth > 0 else { return revealFraction }
    let delta = dividerDragDelta / containerWidth
    return min(max(revealFraction + delta, 0), 1)
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

  private func dividerDragGesture(containerWidth: CGFloat) -> some Gesture {
    DragGesture()
      .updating($dividerDragDelta) { value, state, _ in
        state = value.translation.width
      }
      .onEnded { value in
        guard containerWidth > 0 else { return }
        let delta = value.translation.width / containerWidth
        revealFraction = min(max(revealFraction + delta, 0), 1)
      }
  }

  /// `onTap` が設定されていない呼び出し元（比較モードなど）では、実質的に
  /// 何も起きないジェスチャーを返す（`.gesture` チェーンに常に同じ形の
  /// ジェスチャーを繋いでおいたほうがコードがシンプルになるため）。
  ///
  /// `.named(Self.coordinateSpaceName)` を使うことで、`value.location` は
  /// ズーム・パンされている `imageStack` 自身の `.local` 座標系ではなく、
  /// 変形の影響を受けないコンテナ（`geo.size`）基準の「画面上どこをタップしたか」
  /// を表す座標として得られる。そこから現在のズーム・パンを自前で打ち消して
  /// （`unscaledLocalPoint`）、実際に見えている画像内容のどの位置がタップされたかを求める。
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
  /// `imageStack` は `.scaleEffect(currentScale)` の後に `.offset(currentOffset)`
  /// を適用しているため、逆変換は「オフセットを引く → 中心を基準にスケールで割る」
  /// の順で行う（`scaleEffect` のデフォルトアンカーは中心）。
  private func unscaledLocalPoint(from containerPoint: CGPoint, containerSize: CGSize) -> CGPoint
  {
    let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
    let afterOffset = CGPoint(
      x: containerPoint.x - currentOffset.width, y: containerPoint.y - currentOffset.height)
    let relativeToCenter = CGPoint(x: afterOffset.x - center.x, y: afterOffset.y - center.y)
    let unscaled = CGPoint(
      x: relativeToCenter.x / currentScale, y: relativeToCenter.y / currentScale)
    return CGPoint(x: unscaled.x + center.x, y: unscaled.y + center.y)
  }

  /// コンテナ内でのタップ位置（ズーム・パン無しの `geo.size` 基準ローカル座標）を、
  /// `before`/`after` 画像の正規化座標（左上原点・0...1）に変換する。
  /// 画像は `.aspectRatio(.fit)` でコンテナ内に収まるように描画されており、
  /// コンテナとアスペクト比が異なる場合は左右または上下に余白（レターボックス）が
  /// 生まれるため、単純な比率計算ではなく fit 表示時の実際の縮小率・余白量を考慮する。
  private func normalizedImagePoint(from location: CGPoint, containerSize: CGSize) -> CGPoint {
    let imageSize = CGSize(width: before.width, height: before.height)
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
}

#Preview {
  @Previewable @State var zoomState = ImageZoomState.identity
  @Previewable @State var revealFraction: CGFloat = 0.5

  let size = CGSize(width: 400, height: 300)
  let before = CGImage.solidColor(.systemBlue, size: size)!
  let after = CGImage.solidColor(.systemOrange, size: size)!

  return BeforeAfterImageCompareView(
    before: before, after: after, zoomState: $zoomState, revealFraction: $revealFraction
  )
  .frame(width: 500, height: 375)
  .padding()
}

extension CGImage {
  fileprivate static func solidColor(_ color: PlatformColor, size: CGSize) -> CGImage? {
    let width = Int(size.width)
    let height = Int(size.height)
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.setFillColor(color.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    return context.makeImage()
  }
}

#if canImport(UIKit)
  import UIKit
  private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
  import AppKit
  private typealias PlatformColor = NSColor
#endif
