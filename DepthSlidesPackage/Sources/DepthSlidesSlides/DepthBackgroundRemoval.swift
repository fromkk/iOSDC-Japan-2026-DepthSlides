import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// 深度マップを使って「選択したオブジェクトより手前だけを残し、奥側を背景として
/// 削除する」処理。`DepthBokehBlur` と同じく Core ML とは無関係な純粋な
/// Core Image 処理なので独立させている。
///
/// 深度は 4 モデル共通で「近い = 明るい / 遠い = 暗い」の 8bit グレースケール。
/// タップ位置の深度値 `d` を読み取り、`depth >= d - margin` の画素（＝選択した
/// オブジェクトと同じかそれより手前）を残す。境界は `softness` の幅で滑らかに
/// 透過させる。
enum DepthBackgroundRemoval {
  /// - Parameters:
  ///   - selectionPoint: 残したいオブジェクトの位置（画像に対する正規化座標、
  ///     左上原点・0...1）。
  ///   - margin: 選択位置の深度値からこの分だけ奥までは「同じオブジェクト」と
  ///     みなして残す許容範囲（0...1 の深度値スケール）。
  ///   - softness: マスクの境界をなだらかにする幅（0...1 の深度値スケール）。
  ///   - showsCheckerboard: 削除した部分を市松模様で埋めて可視化する。
  ///     `false` なら透明のまま返す。
  static func apply(
    original: CGImage, depth: CGImage, selectionPoint: CGPoint,
    margin: CGFloat = 0.08, softness: CGFloat = 0.04, showsCheckerboard: Bool = true
  ) -> CGImage? {
    let context = CIContext()
    let originalImage = CIImage(cgImage: original)
    let mask = foregroundMask(
      depth: depth, matchingExtentOf: originalImage, selectionPoint: selectionPoint,
      margin: margin, softness: softness, context: context)

    let background: CIImage
    if showsCheckerboard {
      let checker = CIFilter.checkerboardGenerator()
      checker.color0 = CIColor(red: 0.92, green: 0.92, blue: 0.92)
      checker.color1 = CIColor(red: 0.75, green: 0.75, blue: 0.75)
      checker.width = Float(max(16, min(original.width, original.height) / 40))
      checker.sharpness = 1
      background = (checker.outputImage ?? CIImage(color: .gray)).cropped(to: originalImage.extent)
    } else {
      background = CIImage(color: .clear).cropped(to: originalImage.extent)
    }

    // マスクが明るい(=手前)ほど元画像を、暗い(=奥)ほど背景を採用する。
    let blend = CIFilter.blendWithMask()
    blend.inputImage = originalImage
    blend.backgroundImage = background
    blend.maskImage = mask
    guard let output = blend.outputImage else { return nil }

    let cropped = output.cropped(to: originalImage.extent)
    return context.createCGImage(cropped, from: cropped.extent)
  }

  /// 「残す = 1 / 消す = 0」のマスクを作る。
  /// `DepthBokehBlur.blurMask` と同じ理由で、深度画像は `colorSpace: NSNull()` で
  /// 読み込み（暗黙のガンマ変換を避ける）、定数画像を作らず `CIColorMatrix` の
  /// バイアス項だけで閾値処理を完結させている。
  static func foregroundMask(
    depth: CGImage, matchingExtentOf original: CIImage, selectionPoint: CGPoint,
    margin: CGFloat, softness: CGFloat, context: CIContext
  ) -> CIImage {
    var rawDepth = CIImage(cgImage: depth, options: [.colorSpace: NSNull()])
    if rawDepth.extent.size != original.extent.size {
      let sx = original.extent.width / rawDepth.extent.width
      let sy = original.extent.height / rawDepth.extent.height
      rawDepth = rawDepth.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
    }

    let selected = CGFloat(
      sampleAverageGrayscale(context: context, image: rawDepth, at: selectionPoint))

    // mask = clamp((depth - (selected - margin)) / softness, 0, 1)
    //      = clamp(k * depth + k * (margin - selected), 0, 1)   (k = 1 / softness)
    let k = 1 / max(softness, 0.001)
    let bias = k * (margin - selected)
    let scaled = rawDepth.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
      ])
    return scaled.applyingFilter(
      "CIColorClamp",
      parameters: [
        "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1),
      ])
  }

  /// 正規化座標（左上原点・0...1）を中心とした `size`×`size` 画素の平均グレー値を
  /// 読み取る。1 画素だけだとノイズや細い境界でブレやすいため少し広めに見る。
  /// CIImage は左下原点なので Y を反転する。
  private static func sampleAverageGrayscale(
    context: CIContext, image: CIImage, at normalizedPoint: CGPoint, size: Int = 7
  ) -> Float {
    let half = CGFloat(size / 2)
    let cx = image.extent.origin.x + normalizedPoint.x * image.extent.width
    let cy = image.extent.origin.y + (1 - normalizedPoint.y) * image.extent.height
    var bounds = CGRect(
      x: (cx - half).rounded(.down), y: (cy - half).rounded(.down),
      width: CGFloat(size), height: CGFloat(size))
    bounds = bounds.intersection(image.extent)
    guard !bounds.isNull, bounds.width >= 1, bounds.height >= 1 else { return 0 }

    let width = Int(bounds.width)
    let height = Int(bounds.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    context.render(
      image, toBitmap: &pixels, rowBytes: width * 4, bounds: bounds, format: .RGBA8,
      colorSpace: nil)
    var sum = 0
    for index in stride(from: 0, to: pixels.count, by: 4) {
      sum += Int(pixels[index])
    }
    return Float(sum) / Float(width * height) / 255.0
  }

  /// コード表示・解説用のサンプルコード文字列。
  static let sampleCode = """
    // depth: 近い = 明るい / 遠い = 暗い（0...1）
    // selected: タップ位置の深度値
    // mask = clamp((depth - (selected - margin)) / softness, 0, 1)
    let k = 1 / softness
    let mask = depth
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
        "inputBiasVector": CIVector(x: k * (margin - selected), y: 0, z: 0, w: 0),
      ])
      .applyingFilter("CIColorClamp")

    let blend = CIFilter.blendWithMask()
    blend.inputImage = CIImage(cgImage: original)   // 手前（残す）
    blend.backgroundImage = CIImage(color: .clear)  // 奥（消す）
    blend.maskImage = mask
    """
}
