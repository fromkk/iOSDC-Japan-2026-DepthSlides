import CoreGraphics
import CoreImage
import CoreML
import Foundation

enum DepthEstimationError: Error {
  case modelNotBundled(DepthModel)
  case unsupportedInputFeature
  case unsupportedOutputFeature
  case imageRenderFailed
}

/// Core ML の深度推定モデルを読み込み・実行して、深度マップを `CGImage` として
/// 取得するための actor。モデルごとに入出力の形（ImageType / MultiArrayType、
/// 相対深度 / メートル単位の絶対深度など）が異なるため、モデルの種類に応じて
/// 前処理・後処理を切り替えている。
///
/// NOTE: `depthAnythingV3Small` (da3-small) は `scripts/convert_depth_anything_v3.py`
/// で変換したモデルの入力名 `"image"` / 出力名 `"depth"` に依存している。
/// `depthPro` の入出力名・形状は Hugging Face のモデルカード記載の仕様
/// (`image`, `originalWidth`, `depthMeters`) に基づく。それ以外
/// (`depthAnythingV2Small`, `midasSmall`) は単一入力・単一出力の ImageType
/// モデルとして、モデルの `modelDescription` から実際の入出力名・サイズを
/// 実行時に取得することで、変換スクリプトが生成した正確な名前に依存しないようにしている。
actor DepthEstimator {
  static let shared = DepthEstimator()

  private var compiledModels: [DepthModel: MLModel] = [:]
  private let context = CIContext()

  func estimate(cgImage: CGImage, model: DepthModel) async throws -> CGImage {
    let mlModel = try await loadModel(model)
    switch model {
    case .depthPro:
      return try runDepthPro(cgImage: cgImage, model: mlModel)
    case .depthAnythingV3Small:
      return try runDepthAnythingV3(cgImage: cgImage, model: mlModel)
    case .depthAnythingV2Small, .midasSmall:
      return try runGenericImageModel(cgImage: cgImage, model: mlModel)
    }
  }

  private func loadModel(_ model: DepthModel) async throws -> MLModel {
    if let cached = compiledModels[model] {
      return cached
    }
    guard let packageURL = model.packageURL else {
      throw DepthEstimationError.modelNotBundled(model)
    }
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all
    let compiledURL = try await MLModel.compileModel(at: packageURL)
    let mlModel = try MLModel(contentsOf: compiledURL, configuration: configuration)
    compiledModels[model] = mlModel
    return mlModel
  }

  // MARK: - Depth Anything V2 Small / MiDaS Small (単一 ImageType 入力・単一出力)

  private func runGenericImageModel(cgImage: CGImage, model: MLModel) throws -> CGImage {
    guard
      let inputName = model.modelDescription.inputDescriptionsByName.keys.first,
      let inputDescription = model.modelDescription.inputDescriptionsByName[inputName],
      let imageConstraint = inputDescription.imageConstraint
    else {
      throw DepthEstimationError.unsupportedInputFeature
    }

    let inputImage = CIImage(cgImage: cgImage)
    let targetSize = CGSize(
      width: imageConstraint.pixelsWide, height: imageConstraint.pixelsHigh)
    let resized = inputImage.resized(to: targetSize)
    guard
      let pixelBuffer = context.render(
        resized, pixelFormat: imageConstraint.pixelFormatType)
    else {
      throw DepthEstimationError.imageRenderFailed
    }

    let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: pixelBuffer])
    let prediction = try model.prediction(from: provider)

    guard let outputName = model.modelDescription.outputDescriptionsByName.keys.first,
      let outputValue = prediction.featureValue(for: outputName)
    else {
      throw DepthEstimationError.unsupportedOutputFeature
    }

    let depthImage: CIImage
    if let outputPixelBuffer = outputValue.imageBufferValue {
      depthImage = CIImage(cvPixelBuffer: outputPixelBuffer)
    } else if let multiArray = outputValue.multiArrayValue {
      depthImage = try Self.normalizedGrayscaleImage(from: multiArray)
    } else {
      throw DepthEstimationError.unsupportedOutputFeature
    }

    let restored = depthImage.resized(
      to: CGSize(width: cgImage.width, height: cgImage.height))
    guard let outputImage = context.createCGImage(restored, from: restored.extent) else {
      throw DepthEstimationError.imageRenderFailed
    }
    return outputImage
  }

  // MARK: - Depth Pro (image + originalWidth 入力、depthMeters 出力)

  private func runDepthPro(cgImage: CGImage, model: MLModel) throws -> CGImage {
    guard
      let imageInputDescription = model.modelDescription.inputDescriptionsByName["image"],
      let imageConstraint = imageInputDescription.imageConstraint
    else {
      throw DepthEstimationError.unsupportedInputFeature
    }

    let inputImage = CIImage(cgImage: cgImage)
    let targetSize = CGSize(
      width: imageConstraint.pixelsWide, height: imageConstraint.pixelsHigh)
    let resized = inputImage.resized(to: targetSize)
    guard
      let pixelBuffer = context.render(resized, pixelFormat: imageConstraint.pixelFormatType)
    else {
      throw DepthEstimationError.imageRenderFailed
    }

    // DepthPro.mlpackage の originalWidth 入力は float16 の MultiArray として
    // 変換されている（`coremltools` の get_spec() で確認済み）。
    let originalWidth = try MLMultiArray(shape: [1, 1, 1, 1], dataType: .float16)
    originalWidth[0] = NSNumber(value: Float(cgImage.width))

    let provider = try MLDictionaryFeatureProvider(dictionary: [
      "image": pixelBuffer,
      "originalWidth": originalWidth,
    ])
    let prediction = try model.prediction(from: provider)

    guard
      let depthMeters = prediction.featureValue(for: "depthMeters")?.multiArrayValue
    else {
      throw DepthEstimationError.unsupportedOutputFeature
    }

    let depthImage = try Self.normalizedGrayscaleImage(from: depthMeters)
    let restored = depthImage.resized(
      to: CGSize(width: cgImage.width, height: cgImage.height))
    guard let outputImage = context.createCGImage(restored, from: restored.extent) else {
      throw DepthEstimationError.imageRenderFailed
    }
    return outputImage
  }

  // MARK: - Depth Anything V3 (5階テンソル入力、手動で ImageNet 正規化が必要)

  private func runDepthAnythingV3(cgImage: CGImage, model: MLModel) throws -> CGImage {
    guard
      let inputDescription = model.modelDescription.inputDescriptionsByName["image"],
      let arrayConstraint = inputDescription.multiArrayConstraint,
      arrayConstraint.shape.count == 5
    else {
      throw DepthEstimationError.unsupportedInputFeature
    }

    let height = arrayConstraint.shape[3].intValue
    let width = arrayConstraint.shape[4].intValue
    let targetSize = CGSize(width: width, height: height)

    let inputImage = CIImage(cgImage: cgImage).resized(to: targetSize)
    guard
      let pixelBuffer = context.render(inputImage, pixelFormat: kCVPixelFormatType_32ARGB)
    else {
      throw DepthEstimationError.imageRenderFailed
    }

    let inputArray = try Self.normalizedImageNetTensor(
      from: pixelBuffer, width: width, height: height)

    let provider = try MLDictionaryFeatureProvider(dictionary: ["image": inputArray])
    let prediction = try model.prediction(from: provider)

    guard let depth = prediction.featureValue(for: "depth")?.multiArrayValue else {
      throw DepthEstimationError.unsupportedOutputFeature
    }

    let depthImage = try Self.normalizedGrayscaleImage(from: depth)
    let restored = depthImage.resized(
      to: CGSize(width: cgImage.width, height: cgImage.height))
    guard let outputImage = context.createCGImage(restored, from: restored.extent) else {
      throw DepthEstimationError.imageRenderFailed
    }
    return outputImage
  }

  /// BGRA/ARGB のピクセルバッファを ImageNet 正規化した (1, 1, 3, H, W) の
  /// MLMultiArray に変換する。
  private static func normalizedImageNetTensor(
    from pixelBuffer: CVPixelBuffer, width: Int, height: Int
  ) throws -> MLMultiArray {
    let mean: [Float] = [0.485, 0.456, 0.406]
    let std: [Float] = [0.229, 0.224, 0.225]

    let array = try MLMultiArray(shape: [1, 1, 3, height, width] as [NSNumber], dataType: .float32)
    let strides = array.strides.map(\.intValue)
    let channelStride = strides[2]
    let rowStride = strides[3]
    let colStride = strides[4]
    let destination = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw DepthEstimationError.imageRenderFailed
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let source = base.assumingMemoryBound(to: UInt8.self)

    for y in 0..<height {
      let row = source + y * bytesPerRow
      for x in 0..<width {
        // kCVPixelFormatType_32ARGB のバイト順は B, G, R, A
        let pixel = row + x * 4
        let r = Float(pixel[2]) / 255.0
        let g = Float(pixel[1]) / 255.0
        let b = Float(pixel[0]) / 255.0
        let normalized = [
          (r - mean[0]) / std[0],
          (g - mean[1]) / std[1],
          (b - mean[2]) / std[2],
        ]
        for channel in 0..<3 {
          let offset = channel * channelStride + y * rowStride + x * colStride
          destination[offset] = normalized[channel]
        }
      }
    }

    return array
  }

  /// メートル単位・生スコアなどの MultiArray を min-max 正規化してグレースケール画像にする。
  private static func normalizedGrayscaleImage(from multiArray: MLMultiArray) throws -> CIImage {
    let shape = multiArray.shape.map(\.intValue)
    guard shape.count >= 2 else { throw DepthEstimationError.unsupportedOutputFeature }
    let height = shape[shape.count - 2]
    let width = shape[shape.count - 1]
    // MLMultiArray は必ずしも単純な行優先 (row-major, stride = width) の
    // 連続メモリレイアウトとは限らない（パディング等で異なる場合がある）ため、
    // 実際の strides を使ってオフセットを計算する。これを怠ると
    // （特に正方形でない出力で）斜め方向にずれた画像になる。
    let strides = multiArray.strides.map(\.intValue)
    let rowStride = strides[shape.count - 2]
    let colStride = strides[shape.count - 1]

    var minValue = Float.greatestFiniteMagnitude
    var maxValue = -Float.greatestFiniteMagnitude
    let count = width * height

    var floatValues = [Float](repeating: 0, count: count)
    switch multiArray.dataType {
    case .float32:
      let source = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)
      for y in 0..<height {
        for x in 0..<width {
          let value = source[y * rowStride + x * colStride]
          floatValues[y * width + x] = value
          minValue = min(minValue, value)
          maxValue = max(maxValue, value)
        }
      }
    case .float16:
      // DepthPro などの変換済みモデルは出力が float16 になっていることが多いため、
      // NSNumber 経由のボクシングを避けて Float16 として直接読む。
      let source = multiArray.dataPointer.bindMemory(to: Float16.self, capacity: multiArray.count)
      for y in 0..<height {
        for x in 0..<width {
          let value = Float(source[y * rowStride + x * colStride])
          floatValues[y * width + x] = value
          minValue = min(minValue, value)
          maxValue = max(maxValue, value)
        }
      }
    default:
      // NSNumber 経由の多次元添字（座標指定）は strides を意識せず安全にアクセスできる。
      var key = [NSNumber](repeating: 0, count: shape.count)
      for y in 0..<height {
        for x in 0..<width {
          key[shape.count - 2] = NSNumber(value: y)
          key[shape.count - 1] = NSNumber(value: x)
          let value = multiArray[key].floatValue
          floatValues[y * width + x] = value
          minValue = min(minValue, value)
          maxValue = max(maxValue, value)
        }
      }
    }

    let range = max(maxValue - minValue, .leastNonzeroMagnitude)
    var bytes = [UInt8](repeating: 0, count: width * height)
    for index in 0..<(width * height) {
      let normalized = (floatValues[index] - minValue) / range
      bytes[index] = UInt8(max(0, min(255, normalized * 255)))
    }

    guard
      let provider = CGDataProvider(data: Data(bytes) as CFData),
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      throw DepthEstimationError.imageRenderFailed
    }
    return CIImage(cgImage: cgImage)
  }
}

extension CIImage {
  fileprivate func resized(to size: CGSize) -> CIImage {
    let scaleX = size.width / extent.width
    let scaleY = size.height / extent.height
    var output = transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    output = output.transformed(
      by: CGAffineTransform(translationX: -output.extent.origin.x, y: -output.extent.origin.y))
    return output
  }
}

extension CIContext {
  fileprivate func render(_ image: CIImage, pixelFormat: OSType) -> CVPixelBuffer? {
    var output: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(image.extent.width),
      Int(image.extent.height),
      pixelFormat,
      nil,
      &output
    )
    guard status == kCVReturnSuccess, let output else { return nil }
    render(image, to: output)
    return output
  }
}
