import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// 深度マップを使って、元画像にポートレートモード風の可変ボケをかける。
/// Core ML のモデル管理とは無関係な純粋な Core Image 処理なので、
/// `DepthEstimator` actor には入れず独立させている。
enum DepthBokehBlur {
  /// - Parameter focusPoint: タップなどでユーザーが指定した焦点位置
  ///   （画像に対する正規化座標、左上原点・0...1）。`nil` の場合は従来通り
  ///   「画面内で最も近い被写体」を焦点として扱う。指定した場合は、その位置の
  ///   深度値との差が大きいほど強くぼかす（手前・奥のどちらも指定位置から
  ///   離れていればぼける、実際のカメラのピント面に近い挙動）。
  static func apply(
    original: CGImage, depth: CGImage, focusPoint: CGPoint? = nil, radius: Double = 24
  ) -> CGImage? {
    let context = CIContext()
    let originalImage = CIImage(cgImage: original)
    let mask = blurMask(
      depth: depth, matchingExtentOf: originalImage, focusPoint: focusPoint, context: context)

    let blur = CIFilter.maskedVariableBlur()
    blur.inputImage = originalImage
    blur.mask = mask
    blur.radius = Float(radius)
    guard let output = blur.outputImage else { return nil }

    // ぼかし半径分だけ出力の extent が元画像より広がるため、切り戻す。
    let cropped = output.cropped(to: originalImage.extent)
    return context.createCGImage(cropped, from: cropped.extent)
  }

  /// 深度画像から、ボケの強さを表すマスクを作る。`focusPoint` が nil なら
  /// 「遠いほど明るい」既定のマスク、指定されていれば焦点距離との差分マスク
  /// (`focusDistanceMask` 参照)。`DepthBokehBlur.apply` と `CIFilterBokehBlur.apply`
  /// の両方から使う共通処理。
  static func blurMask(
    depth: CGImage, matchingExtentOf original: CIImage, focusPoint: CGPoint?, context: CIContext
  ) -> CIImage {
    var depthImage = CIImage(cgImage: depth)
    // 焦点との差分計算専用に、色空間を付けずに読み込んだ深度画像も用意する。
    // 通常の CIImage(cgImage:) だと depth の色空間（DeviceGray）に基づいて
    // Core Image の作業色空間へ暗黙にガンマ変換されてしまい、「値の差分」を
    // 計算する焦点距離マスクの意味が狂うおそれがある（参考: ImageBokehAdjust の
    // CIImage.depthMap(from:) が同じ理由で colorSpace: NSNull() を指定している）。
    // 従来のガンマ補正パス（else 節）は色管理込みで調整・検証済みのため、
    // そちらには影響させない。
    var rawDepthImage = CIImage(cgImage: depth, options: [.colorSpace: NSNull()])

    // DepthEstimator は深度画像を元画像と同じ寸法にリサイズして返す前提だが、
    // 念のため寸法が異なる場合は合わせる。
    if depthImage.extent.size != original.extent.size {
      let sx = original.extent.width / depthImage.extent.width
      let sy = original.extent.height / depthImage.extent.height
      let transform = CGAffineTransform(scaleX: sx, y: sy)
      depthImage = depthImage.transformed(by: transform)
      rawDepthImage = rawDepthImage.transformed(by: transform)
    }

    if let focusPoint {
      let focusValue = sampleGrayscaleValue(context: context, image: rawDepthImage, at: focusPoint)
      return focusDistanceMask(depthImage: rawDepthImage, focusValue: focusValue)
    } else {
      // CIMaskedVariableBlur は「マスクが明るいほど強くぼかす」規約。
      // depth は「近い=明るい」なので、そのまま使うと近くの被写体がぼやけてしまう。
      // 反転して「遠い=明るい」にすることで、遠い背景ほど強くぼける。
      let invertedMask = depthImage.applyingFilter("CIColorInvert")

      // min-max正規化された深度は、シーン内で最も近い1点だけがマスク値0になり、
      // 被写体全体としては0付近ではない値を取ることが多い。そのままだと
      // 「近くの被写体」全体にも薄くボケがかかってしまうため、ガンマカーブで
      // 中間〜低めの値をさらに0側へ寄せ、被写体はよりシャープに・背景ほど
      // 急激にボケが強まるようにする（遠い=明るい側の値はほぼ変化しない）。
      return invertedMask.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 3.0])
    }
  }

  /// 焦点位置の深度値との絶対差をマスクにする（差が大きいほど明るい=強くぼける）。
  ///
  /// 実装上の注意点（重要）: 当初は `CIImage(color:)` で焦点の深度値を塗りつぶした
  /// 定数画像を作り `CIColorAbsoluteDifference` で比較していたが、`CIColor` は
  /// （`rawDepthImage` に指定した `colorSpace: NSNull()` とは異なり）暗黙に作業色空間を
  /// 持つため、同じ数値のはずの焦点値が比較時に暗黙のガンマ変換を受けて食い違い、
  /// **タップした真下のピクセルでさえ差分が 0 にならず薄くぼけてしまう**という
  /// 実害のあるバグになっていた（実測: focusValue=0.8235 のとき、`CIImage(color:)`
  /// 経由だと同じ地点の差分が 0.18 も出てしまい、`sensitivity` 込みで blur ≈ 17pt も
  /// かかっていた）。そのため、定数画像を新たに作らず `depthImage` 自身に対する
  /// `CIColorMatrix`（バイアス項で `-focusValue` を引く）と `CIMaximumCompositing`
  /// （符号反転したものとの最大値＝絶対値）だけで完結させ、`depthImage` が持つ
  /// 色空間設定をそのまま使い続けることでこの不整合を避けている。
  ///
  /// `deadzone` は「焦点距離のこの範囲内は完全にシャープなまま」という許容範囲
  /// （実カメラの被写界深度に相当）。これがないと、平面ではない実際の被写体
  /// （顔や器など）は表面内でも深度が微妙に変化するため、タップした点のごく
  /// 近くでもすぐ薄いボケがかかって不自然に見える。
  private static func focusDistanceMask(
    depthImage: CIImage, focusValue: Float, sensitivity: CGFloat = 1.5, deadzone: CGFloat = 0.05
  ) -> CIImage {
    let f = CGFloat(focusValue)
    let positive = depthImage.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: -f, y: -f, z: -f, w: 0),
      ])
    let negative = depthImage.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: f, y: f, z: f, w: 0),
      ])
    // positive/negative の大きい方を取ることで絶対値になる（|x| = max(x, -x)）。
    let absDiff = positive.applyingFilter(
      "CIMaximumCompositing", parameters: ["inputBackgroundImage": negative])

    let biasValue = -(sensitivity * deadzone)
    let matrixed = absDiff.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: sensitivity, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: sensitivity, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: sensitivity, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: biasValue, y: biasValue, z: biasValue, w: 0),
      ])
    return matrixed.applyingFilter(
      "CIColorClamp",
      parameters: [
        "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1),
      ])
  }

  /// 深度画像上の正規化座標（左上原点・0...1）に対応するグレースケール値を読み取る。
  /// CIImage の座標系は左下原点なので Y を反転して変換する。
  private static func sampleGrayscaleValue(
    context: CIContext, image: CIImage, at normalizedPoint: CGPoint
  ) -> Float {
    let x = image.extent.origin.x + normalizedPoint.x * image.extent.width
    let y = image.extent.origin.y + (1 - normalizedPoint.y) * image.extent.height
    let bounds = CGRect(x: x.rounded(.down), y: y.rounded(.down), width: 1, height: 1)
    var pixel: [UInt8] = [0, 0, 0, 0]
    context.render(
      image, toBitmap: &pixel, rowBytes: 4, bounds: bounds, format: .RGBA8, colorSpace: nil)
    return Float(pixel[0]) / 255.0
  }

  /// コード表示モードで使う、上記処理を要約したサンプルコード文字列。
  static let sampleCode = """
    import CoreImage.CIFilterBuiltins

    // depth: 近い = 明るい / 遠い = 暗い（4モデル共通の表現）
    let invertedMask = CIImage(cgImage: depth).applyingFilter("CIColorInvert")

    // 被写体全体がシャープに見えるよう、ガンマカーブで低め〜中間の値を
    // さらに0側へ寄せる（近い部分は0に、遠い部分ほど急にボケが強まる）
    let contrastedMask = invertedMask.applyingFilter(
      "CIGammaAdjust", parameters: ["inputPower": 3.0])

    let blur = CIFilter.maskedVariableBlur()
    blur.inputImage = CIImage(cgImage: original)
    blur.mask = contrastedMask     // 遠い(=明るい)ほど強くぼかす
    blur.radius = 24
    let cropped = blur.outputImage!.cropped(to: CIImage(cgImage: original).extent)
    let blurredCGImage = CIContext().createCGImage(cropped, from: cropped.extent)
    """
}
