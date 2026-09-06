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
    case .embeddedDepth: "写真に埋め込まれた深度情報を取得"
    default: "\(displayName) で深度を取得"
    }
  }

  /// コード表示モードで推定コードの左横に見せる、モデルの入手・Core ML 変換の
  /// Markdown。`scripts/` 配下の変換スクリプトを簡略化したもので、こちらも
  /// 嘘は書かないようにしている。変換が不要なモデル（写真埋め込みの深度・
  /// 変換済みパッケージが配布されているもの）では、コードの代わりに
  /// 入手方法やその旨を説明する。
  ///
  /// `estimationCodeSample` と違い、`depthAnythingV2Small` と `midasSmall` は
  /// 入手経路がまったく異なる（Apple 公式配布 vs ONNX からの自前変換）ため、
  /// それぞれ別の内容を表示する。
  var conversionMarkdown: String {
    switch self {
    case .embeddedDepth:
      """
      ### モデル変換（不要）

      Core ML モデルを使わず、写真（HEIC）に埋め込まれた
      AVDepthData を読み取るだけなので、モデルの入手・変換は不要。
      """
    case .depthAnythingV2Small:
      """
      ### モデル入手（Apple 公式の変換済みを利用）

      ```python
      # Apple が変換済みの Core ML パッケージを公式配布しているため
      # 変換は不要。ダウンロードしてそのまま利用する
      from huggingface_hub import snapshot_download

      snapshot_download(
          repo_id="apple/coreml-depth-anything-v2-small",
          allow_patterns=["DepthAnythingV2SmallF16.mlpackage/*"],
      )
      ```
      """
    case .midasSmall:
      """
      ### モデル変換（ONNX → Core ML）

      ```python
      # coremltools 8+ は ONNX を直接読めないため、onnx2torch で
      # 一度 PyTorch モデルに変換してから trace して渡す
      onnx_model = onnx.load("model-small.onnx")
      torch_model = onnx2torch.convert(onnx_model).eval()
      traced = torch.jit.trace(torch_model, torch.zeros(1, 3, 256, 256))

      mlmodel = ct.convert(
          traced,
          inputs=[ct.ImageType(
              name=input_name,         # ONNX グラフから検出した入出力名
              shape=(1, 3, 256, 256),
              scale=scale, bias=bias,  # ImageNet 正規化を入力側に織り込む
              color_layout=ct.colorlayout.RGB,
          )],
          outputs=[ct.TensorType(name=output_name)],
          convert_to="mlprogram",
          compute_precision=ct.precision.FLOAT16,
      )
      mlmodel.save("MiDaSSmall.mlpackage")
      ```
      """
    case .depthPro:
      """
      ### モデル入手（コミュニティ変換済みを利用）

      ```python
      # Apple 自身は Core ML 形式を配布していないが、Hugging Face の
      # coreml-projects に変換済みパッケージ（約1.9GB）が公開されている。
      # ViT + パッチフュージョンの複雑な構成をゼロから再変換するのは
      # リスクが高いため、これをダウンロードして利用する
      from huggingface_hub import snapshot_download

      snapshot_download(
          repo_id="coreml-projects/DepthPro-coreml",
          allow_patterns=["DepthPro.mlpackage/*"],
      )
      ```
      """
    case .depthAnythingV3Small:
      """
      ### モデル変換（PyTorch → Core ML）

      ```python
      # DA3 の生出力 dict から depth テンソルだけを返す
      # 薄いラッパーを trace して coremltools に渡す
      wrapper = DepthOnlyWrapper(da3.model, depth_key).eval()
      traced = torch.jit.trace(wrapper, (imgs,), strict=False)

      mlmodel = ct.convert(
          traced,
          inputs=[ct.TensorType(name="image", shape=imgs.shape)],
          outputs=[ct.TensorType(name="depth")],
          convert_to="mlprogram",
          compute_precision=ct.precision.FLOAT16,
          minimum_deployment_target=ct.target.iOS17,
      )
      mlmodel.save("DepthAnythingV3Small.mlpackage")
      ```
      """
    }
  }

  var estimationCodeSample: String {
    switch self {
    case .embeddedDepth:
      """
      // Portraitモードなどで撮影した写真の HEIC には、AVDepthData 形式の
      // 深度情報が補助データとして埋め込まれている（機種・撮影条件によっては
      // 埋め込まれていないこともあるため、Depth → Disparity の順に試す）
      let source = CGImageSourceCreateWithData(data as CFData, nil)!
      let info = [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity]
        .lazy
        .compactMap {
          CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, $0) as? [AnyHashable: Any]
        }
        .first!
      let depthData = try AVDepthData(fromDictionaryRepresentation: info)

      // 視差(disparity)形式に統一して取り出す（近い = 値が大きい = 明るい）
      let converted = depthData.converting(
        toDepthDataType: kCVPixelFormatType_DisparityFloat32
      )
      var depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)

      // 深度マップはセンサーの生の向きで格納されているため、本体画像の
      // EXIF Orientation を読み取って同じ回転を適用しないと縦写真が横向きになる
      if let orientation = exifOrientation(from: source) {
        depthImage = depthImage.oriented(orientation)
      }
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
