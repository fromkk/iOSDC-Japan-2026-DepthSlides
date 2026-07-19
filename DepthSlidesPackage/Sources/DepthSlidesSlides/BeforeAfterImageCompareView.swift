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
  @Binding var zoomState: ImageZoomState
  @Binding var revealFraction: CGFloat

  @GestureState private var magnifyDelta: CGFloat = 1
  @GestureState private var panDelta: CGSize = .zero
  @GestureState private var dividerDragDelta: CGFloat = 0

  private let minScale: CGFloat = 1
  private let maxScale: CGFloat = 6
  private let zoomStep: CGFloat = 1.5
  private let handleWidth: CGFloat = 32

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
          .clipped()

        dividerHandle(fraction: fraction, containerSize: geo.size)

        labels

        zoomButtons
          .padding(12)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  /// `before`/`after` は常に同じピクセルサイズ（`DepthEstimator` が深度画像を
  /// 元画像と同じ寸法にリサイズして返すため）だが、コンテナとのアスペクト比が
  /// 一致するとは限らない。`.fit` だとレターボックスが生まれ、実際に描画される
  /// 画像フレームがコンテナ全体 (`containerSize`) より小さくなることがあり、
  /// その場合ハンドル位置（コンテナ基準）とマスクの境界（画像フレーム基準）が
  /// ズレてしまう。`.fill` + `.clipped()` で画像を常にコンテナ全体ぴったりに
  /// 描画することで、マスク・ハンドルの両方を同じ `containerSize` 基準で
  /// 一貫して計算できるようにしている。
  private func imageStack(fraction: CGFloat, containerSize: CGSize) -> some View {
    ZStack {
      Image(decorative: before, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()

      Image(decorative: after, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fill)
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
        label("元画像")
        Spacer()
        label("深度画像")
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
