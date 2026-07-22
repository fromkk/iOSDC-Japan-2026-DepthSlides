import Foundation

/// コード表示モードで見せる、モデルごとの深度取得サンプルコード。
/// `DepthEstimator.swift` の実装を簡略化しつつ、嘘は書かないようにしている。
///
/// `depthAnythingV2Small` と `midasSmall` は実装上まったく同じコードパス
/// （単一の ImageType 入力・単一出力）を通り、入出力の名前もハードコードせず
/// 動的に検出しているため、同じサンプルコードを表示する
/// （MiDaS の変換後モデルの出力名は "depth" のような分かりやすい名前ではなく
/// "var_797" のような自動生成名になるため、決め打ちで書くと誤りになる）。
extension DepthModel {
  /// コード表示モードの見出し。`embeddedDepth` は「推定」ではなく「取得」なので
  /// 他モデルと同じ「〜で深度を取得」というテンプレートに当てはめると
  /// 意味が重複してしまうため専用の文言にする。
  var codeSectionTitle: String {
    switch self {
    case .embeddedDepth: "写真に含まれる深度情報を取得"
    default: "\(displayName) で深度を取得"
    }
  }

  var estimationCodeSample: String {
    switch self {
    case .embeddedDepth:
      """
      // Portraitモードなどで撮影した写真の HEIC には、AVDepthData 形式の
      // 深度情報が補助データとして埋め込まれている（機種・撮影条件によっては
      // 埋め込まれていないこともある）
      let source = CGImageSourceCreateWithData(data as CFData, nil)!
      let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
        source, 0, kCGImageAuxiliaryDataTypeDisparity
      ) as! [AnyHashable: Any]
      let depthData = try AVDepthData(fromDictionaryRepresentation: info)

      // 視差(disparity)形式に統一して取り出す（近い = 値が大きい = 明るい）
      let converted = depthData.converting(
        toDepthDataType: kCVPixelFormatType_DisparityFloat32
      )
      let depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)
      """
    case .depthAnythingV2Small, .midasSmall:
      """
      // モデルごとに入出力の名前が異なる（変換時に自動生成されることもある）ため、
      // ハードコードせず modelDescription から動的に検出する
      let inputName = model.modelDescription.inputDescriptionsByName.keys.first!
      let outputName = model.modelDescription.outputDescriptionsByName.keys.first!

      let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: pixelBuffer])
      let prediction = try model.prediction(from: provider)
      let outputValue = prediction.featureValue(for: outputName)!

      // Depth Anything V2 Small は ImageType 出力（そのまま画像にできる）
      // MiDaS Small は MultiArray 出力（min-max正規化してグレースケール化が必要）
      let depthImage: CIImage
      if let buffer = outputValue.imageBufferValue {
        depthImage = CIImage(cvPixelBuffer: buffer)               // 近い = 明るい
      } else if let scores = outputValue.multiArrayValue {
        depthImage = try normalizedGrayscaleImage(from: scores)   // 近い = 大きい値 = 明るい
      }
      """
    case .depthPro:
      """
      // Depth Pro は image に加えて originalWidth（元画像の幅）も入力する必要がある
      let originalWidth = try MLMultiArray(shape: [1, 1, 1, 1], dataType: .float16)
      originalWidth[0] = NSNumber(value: Float(cgImage.width))

      let provider = try MLDictionaryFeatureProvider(
        dictionary: ["image": pixelBuffer, "originalWidth": originalWidth])
      let prediction = try model.prediction(from: provider)

      // depthMeters はメートル単位の実測距離 = 近いほど値が小さい
      let depthMeters = prediction.featureValue(for: "depthMeters")!.multiArrayValue!
      let depthImage = try normalizedGrayscaleImage(from: depthMeters, invertForNearBright: true)
      """
    case .depthAnythingV3Small:
      """
      // (1, 1, 3, H, W) の5階テンソルに ImageNet 正規化を施して詰める
      let inputArray = try normalizedImageNetTensor(from: pixelBuffer, width: width, height: height)
      let provider = try MLDictionaryFeatureProvider(dictionary: ["image": inputArray])
      let prediction = try model.prediction(from: provider)

      // depth は点群のunprojectionにも使う実深度 = 近いほど値が小さい
      let depth = prediction.featureValue(for: "depth")!.multiArrayValue!
      let depthImage = try normalizedGrayscaleImage(from: depth, invertForNearBright: true)
      """
    }
  }
}
