import CoreGraphics
import CoreImage
import CoreML
import Foundation
import os

enum DepthEstimationError: Error {
  case modelNotBundled(DepthModel)
  case unsupportedInputFeature
  case unsupportedOutputFeature
  case imageRenderFailed
}

/// 推論リクエストが今どの段階にあるか。特に Depth Pro (約1.8GB) は初回の
/// モデルコンパイル・デバイス特化に数十秒〜数分かかり、無言だと「止まっている」
/// ように見えるため、呼び出し側が段階に応じたステータス表示を出せるようにする。
enum DepthEstimationPhase: Sendable {
  /// `.mlpackage` → `.mlmodelc` へのコンパイル中（永続キャッシュがない初回のみ）。
  case compilingModel
  /// コンパイル済みモデルのロード中。この中で OS が GPU/Neural Engine 向けの
  /// 特化コンパイルを行うため、端末での初回は数分かかることがある
  /// （結果は OS がディスクにキャッシュするため2回目以降は速い）。
  case loadingModel
  /// 実際の推論（`MLModel.prediction`）を実行中。
  case inferring
}

typealias DepthEstimationPhaseHandler = @MainActor @Sendable (DepthEstimationPhase) -> Void

/// `DepthEstimator.estimateCached(cgImage:model:cacheKey:)` のキャッシュキー。
/// 同じ画像データ・同じモデルであれば同一キーになり、2回目以降は推論を
/// 実行せずキャッシュ済みの結果をそのまま返す。
struct DepthCacheKey: Hashable {
  let imageData: Data
  let model: DepthModel
}

/// 深度マップキャッシュの本体。actor 隔離の外（ロック保護）に置くことで、
/// actor が別モデルの推論（同期実行の `MLModel.prediction`）で塞がっている間も、
/// キャッシュヒットの読み出しだけは actor のキューに並ばず即座に返せるようにする。
/// これを actor 内の状態にすると、プリフェッチ中に推論済みモデルへ切り替えた際、
/// 実行中の推論が終わるまでキャッシュの辞書引きすらできず「再推論しているように
/// 見える」問題が起きる。
private final class DepthImageCacheStorage: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [DepthCacheKey: CGImage] = [:]

  func image(for key: DepthCacheKey) -> CGImage? {
    lock.withLock { storage[key] }
  }

  func store(_ image: CGImage, for key: DepthCacheKey) {
    lock.withLock { storage[key] = image }
  }
}

/// Core ML の深度推定モデルを読み込み・実行して、深度マップを `CGImage` として
/// 取得するための actor。モデルごとに入出力の形（ImageType / MultiArrayType、
/// 相対深度 / メートル単位の絶対深度など）が異なるため、モデルの種類に応じて
/// 前処理・後処理を切り替えている。
///
/// NOTE: `depthAnythingV3Small` (DA3-SMALL) は `scripts/convert_depth_anything_v3.py`
/// で変換したモデルの入力名 `"image"` / 出力名 `"depth"` に依存している。
/// `depthPro` の入出力名・形状は Hugging Face のモデルカード記載の仕様
/// (`image`, `originalWidth`, `depthMeters`) に基づく。それ以外
/// (`depthAnythingV2Small`, `midasSmall`) は単一入力・単一出力の ImageType
/// モデルとして、モデルの `modelDescription` から実際の入出力名・サイズを
/// 実行時に取得することで、変換スクリプトが生成した正確な名前に依存しないようにしている。
actor DepthEstimator {
  static let shared = DepthEstimator()

  private var compiledModels: [DepthModel: MLModel] = [:]

  /// モデルごとの実行中コンパイル処理。起動時ウォームアップと推論経路の
  /// `loadModel` が同じモデルを同時に要求しても、1つのコンパイルを共有して
  /// 二重に走らせないための台帳。
  private var compileTasks: [DepthModel: Task<URL, any Error>] = [:]
  private var didWarmUp = false

  private let depthImageCache = DepthImageCacheStorage()
  private let context = CIContext()
  private let clock = ContinuousClock()
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "DepthSlides", category: "DepthEstimator")

  func estimate(cgImage: CGImage, model: DepthModel) async throws -> CGImage {
    try await runInference(cgImage: cgImage, model: model, onPhase: nil)
  }

  /// キャッシュ済みの深度マップを actor のキューに並ばずに同期的に取り出す。
  /// 呼び出し側は「推論中...」表示や `estimateCached` の await に入る前に
  /// まずこちらを引くことで、プリフェッチ中の別モデルの推論に待たされずに
  /// キャッシュ済みの結果を即表示できる。
  nonisolated func cachedDepthImage(for cacheKey: DepthCacheKey) -> CGImage? {
    depthImageCache.image(for: cacheKey)
  }

  /// Core ML 推論以外の経路（`EmbeddedDepthExtractor` による写真内蔵深度の抽出）の
  /// 結果も同じキャッシュに載せるための書き込み口。
  nonisolated func storeDepthImage(_ image: CGImage, for cacheKey: DepthCacheKey) {
    depthImageCache.store(image, for: cacheKey)
  }

  /// `estimate(cgImage:model:)` と同じ推論を行うが、`cacheKey` に対する結果を
  /// キャッシュし、同じ画像・同じモデルの組み合わせであれば2回目以降は
  /// 推論をスキップして即座に返す。呼び出し側（`DepthModelCompareView`）が
  /// 画像データから `DepthCacheKey` を1回だけ組み立てて渡す想定。
  /// `onPhase` を渡すと、コンパイル・ロード・推論のフェーズ切り替わりを
  /// MainActor 上で受け取れる（ステータス表示用）。
  func estimateCached(
    cgImage: CGImage, model: DepthModel, cacheKey: DepthCacheKey,
    onPhase: DepthEstimationPhaseHandler? = nil
  ) async throws -> CGImage {
    if let cached = depthImageCache.image(for: cacheKey) {
      return cached
    }
    let result = try await runInference(cgImage: cgImage, model: model, onPhase: onPhase)
    depthImageCache.store(result, for: cacheKey)
    return result
  }

  private func runInference(
    cgImage: CGImage, model: DepthModel, onPhase: DepthEstimationPhaseHandler?
  ) async throws -> CGImage {
    // 実行中の `prediction` は同期実行のため中断できないが、actor のキューで
    // 順番待ちしている呼び出しは、呼び出し元の Task がキャンセル済みなら
    // ここで打ち切って重い推論を開始させない（画面から離れた場合など）。
    try Task.checkCancellation()
    let mlModel = try await loadModel(model, onPhase: onPhase)
    try Task.checkCancellation()
    await onPhase?(.inferring)
    let start = clock.now
    let result: CGImage
    switch model {
    case .embeddedDepth:
      // embeddedDepth は Core ML 推論ではなく `EmbeddedDepthExtractor` が
      // 写真自体の AVDepthData から取り出す（`packageURL` が nil のため
      // 実際には上の `loadModel` が先に `.modelNotBundled` を投げる）。
      // `DepthModelCompareView` 側でこのケースには分岐しないため、ここには
      // 到達しないはずだが、`DepthModel` の全ケースに対して網羅的であることを
      // 保証するために残している。
      throw DepthEstimationError.modelNotBundled(model)
    case .depthPro:
      result = try runDepthPro(cgImage: cgImage, model: mlModel)
    case .depthAnythingV3Small:
      result = try runDepthAnythingV3(cgImage: cgImage, model: mlModel)
    case .depthAnythingV2Small, .midasSmall:
      result = try runGenericImageModel(cgImage: cgImage, model: mlModel)
    }
    logger.info("\(model.rawValue): 推論 \(Self.formatted(self.clock.now - start))")
    return result
  }

  /// 端末で利用可能な全 Core ML モデルについて、コンパイル済みの永続キャッシュが
  /// なければコンパイルして永続化する。アプリ起動時に一度だけ呼ぶ想定
  /// （2回目以降の呼び出しは何もしない）。直列で進め、最重量の depthPro は
  /// 最後に回す。永続化済みのモデルは指紋チェックだけで即スキップされる。
  /// 途中でユーザーが同じモデルの推論を要求した場合は `compileTasks` 経由で
  /// 実行中のコンパイルに相乗りするため、二重コンパイルにはならない。
  func warmUpAllCompiledModels() async {
    guard !didWarmUp else { return }
    didWarmUp = true

    var targets = DepthModel.availableCases.filter { $0.packageURL != nil }
    if let index = targets.firstIndex(of: .depthPro) {
      targets.append(targets.remove(at: index))
    }
    for model in targets {
      guard let packageURL = model.packageURL, let resourceName = model.resourceName else {
        continue
      }
      do {
        _ = try await compiledModelURL(
          for: model, packageURL: packageURL, resourceName: resourceName, onPhase: nil)
      } catch {
        // モデル未変換などで1つ失敗しても、残りのウォームアップは続行する。
        logger.error("\(model.rawValue): 起動時コンパイルに失敗 \(error)")
      }
    }
  }

  /// コンパイル済み .mlmodelc の URL を返す。優先順は
  /// 永続キャッシュ → 実行中のコンパイルへの相乗り → 新規コンパイル+永続化。
  ///
  /// `MLModel.compileModel` の結果は一時ディレクトリに置かれるため、そのままだと
  /// アプリ起動のたびに約1.8GB (Depth Pro) のコンパイルをやり直すことになる。
  /// Application Support に永続化し、同梱の .mlpackage が変わっていなければ再利用する。
  private func compiledModelURL(
    for model: DepthModel, packageURL: URL, resourceName: String,
    onPhase: DepthEstimationPhaseHandler?
  ) async throws -> URL {
    let fingerprint = Self.sourceFingerprint(of: packageURL)
    if let persisted = Self.persistedCompiledModelURL(
      resourceName: resourceName, fingerprint: fingerprint)
    {
      logger.info("\(model.rawValue): 永続化済みのコンパイル結果を再利用")
      return persisted
    }

    await onPhase?(.compilingModel)
    if let inFlight = compileTasks[model] {
      return try await inFlight.value
    }

    let task = Task<URL, any Error> {
      let compileStart = clock.now
      let tempCompiledURL = try await MLModel.compileModel(at: packageURL)
      let compiledURL: URL
      do {
        compiledURL = try Self.persistCompiledModel(
          at: tempCompiledURL, resourceName: resourceName, fingerprint: fingerprint)
      } catch {
        // 永続化に失敗しても、一時ディレクトリのコンパイル結果でロードは続行できる
        // （次回起動時にまたコンパイルし直しになるだけ）。
        logger.error("\(model.rawValue): コンパイル結果の永続化に失敗 \(error)")
        compiledURL = tempCompiledURL
      }
      logger.info("\(model.rawValue): コンパイル \(Self.formatted(self.clock.now - compileStart))")
      return compiledURL
    }
    compileTasks[model] = task
    defer { compileTasks[model] = nil }
    return try await task.value
  }

  private func loadModel(_ model: DepthModel, onPhase: DepthEstimationPhaseHandler?) async throws
    -> MLModel
  {
    if let cached = compiledModels[model] {
      return cached
    }
    guard let packageURL = model.packageURL, let resourceName = model.resourceName else {
      throw DepthEstimationError.modelNotBundled(model)
    }

    let compiledURL = try await compiledModelURL(
      for: model, packageURL: packageURL, resourceName: resourceName, onPhase: onPhase)

    try Task.checkCancellation()
    await onPhase?(.loadingModel)
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all
    let loadStart = clock.now
    let mlModel = try MLModel(contentsOf: compiledURL, configuration: configuration)
    logger.info("\(model.rawValue): ロード \(Self.formatted(self.clock.now - loadStart))")
    compiledModels[model] = mlModel
    return mlModel
  }

  // MARK: - コンパイル済みモデルの永続化

  /// `Application Support/CompiledDepthModels/` ディレクトリ。
  private static func compiledModelsDirectory() throws -> URL {
    let base = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let directory = base.appendingPathComponent("CompiledDepthModels", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// 同梱 .mlpackage の「指紋」。scripts/ でモデルを変換し直したら永続キャッシュを
  /// 無効化できるよう、パッケージ内の全ファイル数と合計バイト数を使う
  /// （更新日時はビルド時のリソースコピーで変わりうるため使わない）。
  private static func sourceFingerprint(of packageURL: URL) -> String {
    var totalSize: UInt64 = 0
    var fileCount = 0
    if let enumerator = FileManager.default.enumerator(
      at: packageURL, includingPropertiesForKeys: [.fileSizeKey])
    {
      for case let url as URL in enumerator {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
          totalSize += UInt64(size)
          fileCount += 1
        }
      }
    }
    return "\(fileCount)-\(totalSize)"
  }

  /// 永続化済みの .mlmodelc があり、かつ変換元の .mlpackage が変わっていなければ
  /// その URL を返す。
  private static func persistedCompiledModelURL(resourceName: String, fingerprint: String) -> URL? {
    guard let directory = try? compiledModelsDirectory() else { return nil }
    let modelURL = directory.appendingPathComponent(resourceName + ".mlmodelc")
    let stampURL = directory.appendingPathComponent(resourceName + ".fingerprint")
    guard FileManager.default.fileExists(atPath: modelURL.path),
      let stored = try? String(contentsOf: stampURL, encoding: .utf8),
      stored == fingerprint
    else { return nil }
    return modelURL
  }

  /// 一時ディレクトリのコンパイル結果を Application Support へ移動し、変換元の
  /// 指紋を書き込んで次回起動から再利用できるようにする。
  private static func persistCompiledModel(
    at tempURL: URL, resourceName: String, fingerprint: String
  ) throws -> URL {
    let directory = try compiledModelsDirectory()
    let modelURL = directory.appendingPathComponent(resourceName + ".mlmodelc")
    let stampURL = directory.appendingPathComponent(resourceName + ".fingerprint")
    if FileManager.default.fileExists(atPath: modelURL.path) {
      try FileManager.default.removeItem(at: modelURL)
    }
    try FileManager.default.moveItem(at: tempURL, to: modelURL)
    try fingerprint.write(to: stampURL, atomically: true, encoding: .utf8)
    return modelURL
  }

  private static func formatted(_ duration: Duration) -> String {
    let seconds =
      Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    return String(format: "%.2fs", seconds)
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

    let depthImage = try Self.normalizedGrayscaleImage(
      from: depthMeters, invertForNearBright: true)
    let restored = depthImage.resized(
      to: CGSize(width: cgImage.width, height: cgImage.height))
    guard let outputImage = context.createCGImage(restored, from: restored.extent) else {
      throw DepthEstimationError.imageRenderFailed
    }
    return outputImage
  }

  // MARK: - Depth Anything 3 (5階テンソル入力、手動で ImageNet 正規化が必要)

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

    let depthImage = try Self.normalizedGrayscaleImage(from: depth, invertForNearBright: true)
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
        // kCVPixelFormatType_32ARGB のバイト順は A, R, G, B
        // (実測で確認済み: 純赤ピクセルをレンダリングすると [255,255,0,0] になる)
        let pixel = row + x * 4
        let r = Float(pixel[1]) / 255.0
        let g = Float(pixel[2]) / 255.0
        let b = Float(pixel[3]) / 255.0
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
  ///
  /// - Parameter invertForNearBright: モデルの生の出力値が「視差 (disparity)」
  ///   （近いほど値が大きい）ではなく「実際の深度」（近いほど値が小さい）を
  ///   表す場合に `true` を指定する。`EmbeddedDepthExtractor` の AVDepthData 由来の
  ///   視差可視化や、Apple 配布の Depth Anything V2 Small・MiDaS の生スコアは
  ///   視差系（近い=明るい）なので `false` のままでよいが、Depth Pro の
  ///   `depthMeters`（実測メートル）や Depth Anything 3 の `depth`（点群の
  ///   unprojection に使う実深度）はそのまま min-max 正規化すると近い場所ほど
  ///   暗く写り、他モデルと明暗が反転してしまうため `true` にして反転する。
  private static func normalizedGrayscaleImage(
    from multiArray: MLMultiArray, invertForNearBright: Bool = false
  ) throws -> CIImage {
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
      #if arch(x86_64)
        // Swift の Float16 は macOS x86_64 では利用できないため、
        // UInt16 のビットパターンとして読んで手動で Float に変換する。
        let source = multiArray.dataPointer.bindMemory(to: UInt16.self, capacity: multiArray.count)
        for y in 0..<height {
          for x in 0..<width {
            let value = Self.float(fromHalfBits: source[y * rowStride + x * colStride])
            floatValues[y * width + x] = value
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
          }
        }
      #else
        let source = multiArray.dataPointer.bindMemory(to: Float16.self, capacity: multiArray.count)
        for y in 0..<height {
          for x in 0..<width {
            let value = Float(source[y * rowStride + x * colStride])
            floatValues[y * width + x] = value
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
          }
        }
      #endif
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
      var normalized = (floatValues[index] - minValue) / range
      if invertForNearBright {
        normalized = 1 - normalized
      }
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

  #if arch(x86_64)
    /// IEEE 754 binary16 のビットパターンを Float に変換する。
    /// Swift の `Float16` が使えない macOS x86_64 向けのフォールバック。
    private static func float(fromHalfBits bits: UInt16) -> Float {
      let sign = UInt32(bits & 0x8000) << 16
      let exponent = Int((bits >> 10) & 0x1F)
      let mantissa = UInt32(bits & 0x03FF)

      let resultBits: UInt32
      switch exponent {
      case 0:
        if mantissa == 0 {
          // ±0
          resultBits = sign
        } else {
          // 非正規化数: 正規化しながら指数を調整する
          var m = mantissa
          var e: Int32 = -1
          repeat {
            m <<= 1
            e += 1
          } while (m & 0x0400) == 0
          m &= 0x03FF
          resultBits = sign | UInt32(Int32(127 - 15 - e) << 23) | (m << 13)
        }
      case 0x1F:
        // ±Inf / NaN
        resultBits = sign | 0x7F80_0000 | (mantissa << 13)
      default:
        resultBits = sign | UInt32(exponent + 127 - 15) << 23 | (mantissa << 13)
      }
      return Float(bitPattern: resultBits)
    }
  #endif
}

/// アプリ起動時に呼ぶ想定の公開エントリポイント。端末で利用可能な全モデルのうち、
/// コンパイル済み永続キャッシュがないものを裏で直列にコンパイル・永続化しておく
/// （`DepthEstimator` 自体はモジュール内部のため、関数として公開する）。
public func warmUpDepthModelCompilation() async {
  await DepthEstimator.shared.warmUpAllCompiledModels()
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
