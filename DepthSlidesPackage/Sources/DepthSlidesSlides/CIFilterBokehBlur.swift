import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// 深度マップを使ったボケ表現に使える Core Image のブラー系フィルター。
/// `18_BokehBlurComparison` スライドの箇条書きと同じ7種類。
enum BokehFilterKind: String, CaseIterable, Identifiable {
  case boxBlur, discBlur, gaussianBlur, maskedVariableBlur, zoomBlur, motionBlur, bokehBlur

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .boxBlur: "CIBoxBlur"
    case .discBlur: "CIDiscBlur"
    case .gaussianBlur: "CIGaussianBlur"
    case .maskedVariableBlur: "CIMaskedVariableBlur"
    case .zoomBlur: "CIZoomBlur"
    case .motionBlur: "CIMotionBlur"
    case .bokehBlur: "CIBokehBlur"
    }
  }
}

/// `BokehFilterKind` ごとに使うパラメーターをまとめて持つ。フィルターを
/// 切り替えても他フィルターの値はそのまま保持される（お互いに独立したフィールド）。
struct BokehFilterParameters: Equatable {
  /// box/disc/gaussian/maskedVariableBlur/motionBlur/bokehBlur 共通の半径。
  var radius: CGFloat = 24
  /// zoomBlur の強さ (inputAmount)。
  var amount: CGFloat = 20
  /// motionBlur の角度 (ラジアン)。UI 上は度で表示・変換する。
  var angle: CGFloat = 0
  /// bokehBlur のリング量 (inputRingAmount)。
  var ringAmount: CGFloat = 0
  /// bokehBlur のリングサイズ (inputRingSize)。
  var ringSize: CGFloat = 0.1
  /// bokehBlur のソフトネス (inputSoftness)。
  var softness: CGFloat = 1
}

/// `DepthBokehBlur` (CIMaskedVariableBlur 固定) とは別に、7種類のブラー系
/// フィルターを切り替えて深度ベースのボケを比較するためのシミュレーター用処理。
/// マスクの作り方は `DepthBokehBlur.blurMask` をそのまま再利用する。
enum CIFilterBokehBlur {
  static func apply(
    original: CGImage, depth: CGImage, filter: BokehFilterKind,
    parameters: BokehFilterParameters, focusPoint: CGPoint? = nil
  ) -> CGImage? {
    let context = CIContext()
    let originalImage = CIImage(cgImage: original)
    let mask = DepthBokehBlur.blurMask(
      depth: depth, matchingExtentOf: originalImage, focusPoint: focusPoint, context: context)

    let outputImage: CIImage
    if filter == .maskedVariableBlur {
      // マスクをそのまま画素ごとのボケ半径として使う（空間的に変化するボケ）。
      let blur = CIFilter.maskedVariableBlur()
      blur.inputImage = originalImage
      blur.mask = mask
      blur.radius = Float(parameters.radius)
      guard let result = blur.outputImage else { return nil }
      outputImage = result
    } else {
      // 他の6フィルターは画素ごとに変化するボケ半径を持てないため、画像
      // 全体に一様なボケをかけてから、CIMaskedVariableBlur と同じ「マスクが
      // 明るい(=遠い)ほどボケ済みを採用」という規約で CIBlendWithMask 合成する。
      guard let blurred = uniformBlur(originalImage, filter: filter, parameters: parameters)
      else { return nil }
      let blend = CIFilter.blendWithMask()
      blend.inputImage = blurred
      blend.backgroundImage = originalImage
      blend.maskImage = mask
      guard let result = blend.outputImage else { return nil }
      outputImage = result
    }

    let cropped = outputImage.cropped(to: originalImage.extent)
    return context.createCGImage(cropped, from: cropped.extent)
  }

  /// 画像全体に一様なボケをかける。box/disc/gaussian/motion/bokeh は出力の
  /// extent が無限に広がる（端が透明になりうる）ため、`clampedToExtent()` で
  /// 端をエッジピクセルの引き伸ばしにしてからフィルターを適用する。
  private static func uniformBlur(
    _ image: CIImage, filter: BokehFilterKind, parameters: BokehFilterParameters
  ) -> CIImage? {
    let clamped = image.clampedToExtent()
    switch filter {
    case .boxBlur:
      let f = CIFilter.boxBlur()
      f.inputImage = clamped
      f.radius = Float(parameters.radius)
      return f.outputImage
    case .discBlur:
      let f = CIFilter.discBlur()
      f.inputImage = clamped
      f.radius = Float(parameters.radius)
      return f.outputImage
    case .gaussianBlur:
      let f = CIFilter.gaussianBlur()
      f.inputImage = clamped
      f.radius = Float(parameters.radius)
      return f.outputImage
    case .zoomBlur:
      let f = CIFilter.zoomBlur()
      f.inputImage = clamped
      f.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
      f.amount = Float(parameters.amount)
      return f.outputImage
    case .motionBlur:
      let f = CIFilter.motionBlur()
      f.inputImage = clamped
      f.radius = Float(parameters.radius)
      f.angle = Float(parameters.angle)
      return f.outputImage
    case .bokehBlur:
      let f = CIFilter.bokehBlur()
      f.inputImage = clamped
      f.radius = Float(parameters.radius)
      f.ringAmount = Float(parameters.ringAmount)
      f.ringSize = Float(parameters.ringSize)
      f.softness = Float(parameters.softness)
      return f.outputImage
    case .maskedVariableBlur:
      return nil  // apply(...) 側で個別に処理するため到達しない
    }
  }
}
