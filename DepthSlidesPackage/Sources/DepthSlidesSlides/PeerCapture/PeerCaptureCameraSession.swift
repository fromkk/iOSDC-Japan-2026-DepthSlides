#if os(iOS)
  import AVFoundation
  import CoreImage
  import Foundation
  import ImageIO
  import OSLog

  private let logger = Logger(
    subsystem: "info.fromkk.DepthSlides", category: "PeerCaptureCameraSession")

  /// iPhone側: Depth配信を必ず有効にしたカメラセッションで撮影する。
  /// 撮影結果は`EmbeddedDepthExtractor.hasEmbeddedDepth`で実際に検証し、
  /// Depthが含まれていない写真は`capturePhotoVerifyingDepth()`の外へ絶対に出さない。
  @MainActor
  final class PeerCaptureCameraSession: NSObject {
    enum CaptureError: Error {
      case noDepthCapableCameraAvailable
      case configurationFailed
      case captureFailed(Error)
      case missingFileRepresentation
      case depthNotEmbedded
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<Data, Error>?
    private var activeDevice: AVCaptureDevice?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    // AVCaptureSessionのstartRunning/stopRunningはブロッキング呼び出しのためバックグラウンド
    // スレッドで呼ぶ必要があるが、Swift 6の並行性検査はMainActor隔離プロパティを
    // 別Taskへ直接「送る」ことを警告する。開始/停止呼び出し自体はドキュメント上
    // どのスレッドからでも安全なため、@unchecked Sendableな小さな箱に包んで送る。
    private lazy var sessionBox = SessionRunner(session: session)

    // MARK: - Feature B: ライブプレビュー(~15fps)

    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let previewQueue = DispatchQueue(label: "info.fromkk.DepthSlides.peercapture.preview")
    /// ~15fpsにスロットリングされたJPEGプレビューフレームのストリーム。
    /// `captureOutput(_:didOutput:from:)`(previewQueueで発火、MainActor外)から
    /// 書き込まれるため`nonisolated`。
    nonisolated let previewFrames: AsyncStream<Data>
    nonisolated private let previewFramesContinuation: AsyncStream<Data>.Continuation
    // 非Sendableな状態をMainActor外で完結させる、上記`SessionRunner`と同じパターン。
    private let previewEncoder = PreviewFrameEncoder(
      targetLongEdge: 480, minFrameInterval: 1.0 / 15.0)

    override init() {
      (previewFrames, previewFramesContinuation) = AsyncStream<Data>.makeStream(
        bufferingPolicy: .bufferingNewest(1))
      super.init()
    }

    func configure() throws {
      session.beginConfiguration()
      defer { session.commitConfiguration() }

      session.sessionPreset = .photo

      let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [
          .builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera,
          .builtInTrueDepthCamera, .builtInWideAngleCamera,
        ],
        mediaType: .video,
        position: .unspecified
      )
      // デフォルトのactiveFormatだけでなく、そのデバイスが持つ全フォーマットの中に
      // Depth対応のものが1つでもあればよい(後でsetPreferredDepthFormatIfAvailable(_:)が
      // 実際に使うフォーマットを選び直す)。activeFormatだけで判定すると、たまたま
      // デフォルトがDepth非対応なだけの機種を早々に候補から外してしまう。
      guard
        let device = discovery.devices.first(where: { device in
          device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
        })
      else {
        throw CaptureError.noDepthCapableCameraAvailable
      }

      let input: AVCaptureDeviceInput
      do {
        input = try AVCaptureDeviceInput(device: device)
      } catch {
        throw CaptureError.configurationFailed
      }
      guard session.canAddInput(input) else { throw CaptureError.configurationFailed }
      session.addInput(input)
      activeDevice = device
      selectDepthFriendlyFormatIfAvailable(for: device)

      guard session.canAddOutput(photoOutput) else { throw CaptureError.configurationFailed }
      session.addOutput(photoOutput)

      guard photoOutput.isDepthDataDeliverySupported else {
        throw CaptureError.noDepthCapableCameraAvailable
      }
      photoOutput.isDepthDataDeliveryEnabled = true

      // ライブプレビュー配信はbest-effort。追加に失敗してもDepth保証付き撮影の
      // 本筋は妨げないよう、ここではthrowしない。
      videoDataOutput.setSampleBufferDelegate(self, queue: previewQueue)
      videoDataOutput.alwaysDiscardsLateVideoFrames = true
      if session.canAddOutput(videoDataOutput) {
        session.addOutput(videoDataOutput)
      }

      applyDepthSafeZoom()
      setUpRotationCoordinatorIfNeeded()
    }

    /// デバイスのデフォルトの`activeFormat`は、Depthが1点固定ズーム(例:ちょうど4.0倍)
    /// でしか使えないものになっていることがある。iPhone純正カメラのPhotoモード
    /// (Portraitモードを明示的に選ばなくてもDepthが付くことがある)に近い体験にするため、
    /// そのデバイスが持つフォーマットの中から「1倍(無ズーム)でもDepthが使える」ものを
    /// 探して明示的に選び直す。見つからなければデフォルトのままにする。
    private func selectDepthFriendlyFormatIfAvailable(for device: AVCaptureDevice) {
      let candidate = device.formats.first { format in
        guard !format.supportedDepthDataFormats.isEmpty else { return false }
        return format.supportedVideoZoomRangesForDepthDataDelivery.contains { $0.contains(1.0) }
      }
      guard let candidate else {
        logger.log("selectDepthFriendlyFormatIfAvailable: 1倍でDepth対応のフォーマットは見つからず")
        return
      }
      do {
        try device.lockForConfiguration()
        device.activeFormat = candidate
        device.unlockForConfiguration()
        logger.log(
          "selectDepthFriendlyFormatIfAvailable: 1倍でDepth対応のフォーマットに切り替えた: \(candidate.supportedVideoZoomRangesForDepthDataDelivery.map { "\($0.lowerBound)...\($0.upperBound)" }, privacy: .public)"
        )
      } catch {
        logger.error(
          "selectDepthFriendlyFormatIfAvailable failed: \(error.localizedDescription, privacy: .public)"
        )
      }
    }

    // MARK: - 回転補正

    /// `AVCaptureVideoPreviewLayer`が実際に画面に出た時点で`CameraPreviewView`から呼ばれる。
    /// (縦/横どちらで持っても正しい向きにするには、90度固定ではなく実機の向きを
    /// 継続的に監視する`AVCaptureDevice.RotationCoordinator`が必要。プレビュー用の
    /// 回転角(`videoRotationAngleForHorizonLevelPreview`)は、実在するpreviewLayerを
    /// 渡さないと常に0度を返す仕様のため、Viewから渡してもらう必要がある)
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
      previewLayer = layer
      setUpRotationCoordinatorIfNeeded()
    }

    private func setUpRotationCoordinatorIfNeeded() {
      guard rotationCoordinator == nil, let device = activeDevice, let previewLayer else { return }
      let coordinator = AVCaptureDevice.RotationCoordinator(
        device: device, previewLayer: previewLayer)
      rotationCoordinator = coordinator

      applyPreviewRotationAngle(coordinator.videoRotationAngleForHorizonLevelPreview)

      previewRotationObservation = coordinator.observe(
        \.videoRotationAngleForHorizonLevelPreview, options: [.new]
      ) { [weak self] _, change in
        guard let angle = change.newValue else { return }
        Task { @MainActor in self?.applyPreviewRotationAngle(angle) }
      }
      // NOTE: photoOutput側(videoRotationAngleForHorizonLevelCapture)には意図的に
      // 手を出さない。ここに回転角を設定するとDepth Data Deliveryが無効になる
      // (Depthが埋め込まれなくなる)現象を実機で確認したため。photoOutputは
      // 何もしなくても自動で正しい向きの写真を出力してくれる。
    }

    /// 「今どちらを向けてフレーミングしているか」に対応する角度。プレビュー層本体と、
    /// Macへライブ配信するvideoDataOutputの両方に適用する(どちらも"今見えているもの")。
    private func applyPreviewRotationAngle(_ angle: CGFloat) {
      if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(angle)
      {
        connection.videoRotationAngle = angle
      }
      if let connection = videoDataOutput.connection(with: .video),
        connection.isVideoRotationAngleSupported(angle)
      {
        connection.videoRotationAngle = angle
      }
    }

    /// タップされた位置(`AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)`
    /// で変換済みの、0,0〜1,1のデバイス座標)にフォーカスと露出を合わせる。
    func focus(at devicePoint: CGPoint) {
      guard let device = activeDevice else { return }
      do {
        try device.lockForConfiguration()
        if device.isFocusPointOfInterestSupported {
          device.focusPointOfInterest = devicePoint
          device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported {
          device.exposurePointOfInterest = devicePoint
          device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
      } catch {
        logger.error("focus(at:) failed: \(error.localizedDescription, privacy: .public)")
      }
    }

    /// Depth Data Deliveryが有効な状態で使えるズーム範囲は機種・フォーマットによって
    /// 大きく異なり、実機では単一の固定値(例: ちょうど4.0倍のみ)や、1倍を含まない
    /// 連続範囲(例: 2.0〜10.0倍)しか許容しないことも確認している。できるだけ自然な
    /// 画角(1倍=無ズーム)に近づけたいので、初期状態ではDepth対応範囲の中で最も
    /// 1倍に近い値を選ぶ(範囲に1倍そのものが含まれていればそれを使う)。
    private func applyDepthSafeZoom() {
      guard let device = activeDevice else { return }
      let depthSafeRanges = device.activeFormat.supportedVideoZoomRangesForDepthDataDelivery
      guard let factor = Self.nearestZoomFactor(to: 1.0, in: depthSafeRanges) else { return }

      logger.log(
        "applyDepthSafeZoom: depthSafeRanges=\(depthSafeRanges.map { "\($0.lowerBound)...\($0.upperBound)" }, privacy: .public) applied=\(factor, privacy: .public)"
      )
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = factor
        device.unlockForConfiguration()
      } catch {
        logger.error("applyDepthSafeZoom failed: \(error.localizedDescription, privacy: .public)")
      }
    }

    /// 現在のフォーマットでDepthを保ったまま実際に選べる35mm換算焦点距離(mm)の範囲。
    /// 複数の不連続な区間がある場合は最も幅の広いものを使う。範囲が存在しない
    /// (Depth非対応)場合や、実質1点しかなく選択の意味が無い場合はnilを返す
    /// (Viewはこれを見てズーム選択UIを出すかどうかを決める)。
    var depthSafeFocalLengthRangeMM: ClosedRange<CGFloat>? {
      guard let device = activeDevice else { return nil }
      let format = device.activeFormat
      let baseFocalLength = Self.equivalentFocalLength35mm(for: format)
      guard baseFocalLength > 0 else { return nil }
      let ranges = format.supportedVideoZoomRangesForDepthDataDelivery
      guard
        let widest = ranges.max(by: {
          ($0.upperBound - $0.lowerBound) < ($1.upperBound - $1.lowerBound)
        }
        )
      else { return nil }
      let lowerMM = widest.lowerBound * baseFocalLength
      let upperMM = widest.upperBound * baseFocalLength
      guard upperMM - lowerMM > 1 else { return nil }
      return lowerMM...upperMM
    }

    /// 目標の35mm換算焦点距離(mm)に、Depthを保ったまま最も近づくようズーム倍率を設定する。
    @discardableResult
    func setZoom(toFocalLengthMM targetMM: CGFloat) -> Bool {
      guard let device = activeDevice else { return false }
      let format = device.activeFormat
      let baseFocalLength = Self.equivalentFocalLength35mm(for: format)
      guard baseFocalLength > 0 else { return false }
      let desiredFactor = targetMM / baseFocalLength
      let depthSafeRanges = format.supportedVideoZoomRangesForDepthDataDelivery
      guard let factor = Self.nearestZoomFactor(to: desiredFactor, in: depthSafeRanges) else {
        return false
      }
      logger.log(
        "setZoom(toFocalLengthMM: \(targetMM, privacy: .public)): desired=\(desiredFactor, privacy: .public) applied=\(factor, privacy: .public)"
      )
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = factor
        device.unlockForConfiguration()
        return true
      } catch {
        return false
      }
    }

    /// フォーマットの対角画角(度)から35mm判換算焦点距離を逆算する。
    /// 機種によって広角レンズの実焦点距離が異なる(24mm前後〜26mm前後など)ため、
    /// 固定のズーム倍率テーブルではなく画角から都度計算する。
    private static func equivalentFocalLength35mm(for format: AVCaptureDevice.Format) -> CGFloat {
      let fovRadians = CGFloat(format.videoFieldOfView) * .pi / 180
      guard fovRadians > 0 else { return 0 }
      let diagonal35mm: CGFloat = 43.2666  // 36mm x 24mmフルサイズの対角線長
      return (diagonal35mm / 2) / tan(fovRadians / 2)
    }

    /// 複数の(不連続なこともある)ズーム範囲の中から、目標値に最も近い値を選ぶ。
    /// 範囲が空ならnil。
    private static func nearestZoomFactor(to desired: CGFloat, in ranges: [ClosedRange<CGFloat>])
      -> CGFloat?
    {
      guard !ranges.isEmpty else { return nil }
      var best = desired
      var bestDistance = CGFloat.greatestFiniteMagnitude
      for range in ranges {
        let clamped = max(range.lowerBound, min(desired, range.upperBound))
        let distance = abs(clamped - desired)
        if distance < bestDistance {
          bestDistance = distance
          best = clamped
        }
      }
      return best
    }

    func startRunning() {
      let box = sessionBox
      Task.detached(priority: .userInitiated) {
        box.start()
      }
    }

    func stopRunning() {
      let box = sessionBox
      Task.detached(priority: .userInitiated) {
        box.stop()
      }
    }

    func capturePhotoVerifyingDepth() async throws -> Data {
      let settings: AVCapturePhotoSettings
      if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
        settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
      } else {
        settings = AVCapturePhotoSettings()
      }
      settings.isDepthDataDeliveryEnabled = true
      settings.embedsDepthDataInPhoto = true

      // photoOutputの接続に回転角を設定するとDepth Data Deliveryが無効になるため
      // (setUpRotationCoordinatorIfNeeded内のNOTE参照)、シャッターを切る瞬間の
      // 実機の向きだけ控えておき、撮影後にEXIF Orientationを書き換えて補正する。
      // 何もしないと写真のEXIFは縦持ち前提の固定値になり、横持ちで撮った写真が
      // 受信側(Mac)で90度回転して表示される。
      let captureAngle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture

      let data = try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Data, Error>) in
        captureContinuation = continuation
        photoOutput.capturePhoto(with: settings, delegate: self)
      }

      guard EmbeddedDepthExtractor.hasEmbeddedDepth(in: data) else {
        throw CaptureError.depthNotEmbedded
      }

      guard let captureAngle,
        let corrected = Self.orientationCorrectedData(data, captureAngle: captureAngle),
        EmbeddedDepthExtractor.hasEmbeddedDepth(in: corrected)
      else {
        logger.error("orientation correction skipped or failed; returning original photo data")
        return data
      }
      return corrected
    }

    /// 撮影の瞬間の回転角(0/90/180/270度)をEXIF Orientationへ変換し、
    /// `CGImageDestinationCopyImageSource`によるロスレスコピーでメタデータだけ
    /// 書き換える。画素は再エンコードしないため、埋め込みDepthも保持される
    /// (呼び出し側で念のため`hasEmbeddedDepth`を再検証している)。
    private static func orientationCorrectedData(_ data: Data, captureAngle: CGFloat) -> Data? {
      let normalized = (captureAngle.truncatingRemainder(dividingBy: 360) + 360)
        .truncatingRemainder(dividingBy: 360)
      let orientation: CGImagePropertyOrientation =
        switch Int(normalized.rounded()) {
        case 90: .right
        case 180: .down
        case 270: .left
        default: .up
        }

      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let type = CGImageSourceGetType(source)
      else { return nil }
      let output = NSMutableData()
      guard
        let destination = CGImageDestinationCreateWithData(
          output, type, CGImageSourceGetCount(source), nil)
      else { return nil }
      let options = [kCGImageDestinationOrientation: orientation.rawValue] as CFDictionary
      var copyError: Unmanaged<CFError>?
      guard CGImageDestinationCopyImageSource(destination, source, options, &copyError) else {
        logger.error(
          "CGImageDestinationCopyImageSource failed: \(String(describing: copyError?.takeRetainedValue()), privacy: .public)"
        )
        return nil
      }
      return output as Data
    }
  }

  /// `AVCaptureSession`はSendableではないため、start/stopをバックグラウンドの
  /// `Task.detached`から安全に呼べるよう`@unchecked Sendable`な箱に包む。
  /// (`AVCaptureSession.startRunning()/stopRunning()`はどのスレッドから呼んでも
  /// 安全、というのはApple公式ドキュメントの記載どおり)
  private final class SessionRunner: @unchecked Sendable {
    private let session: AVCaptureSession

    init(session: AVCaptureSession) {
      self.session = session
    }

    func start() {
      guard !session.isRunning else { return }
      session.startRunning()
    }

    func stop() {
      guard session.isRunning else { return }
      session.stopRunning()
    }
  }

  /// 経過時間ベースで~15fpsにスロットリングし、縮小・JPEGエンコードする。
  /// `AVCaptureVideoDataOutput`専用キュー上(MainActor外)で完結させるため
  /// `@unchecked Sendable`。時間チェックを変換処理より先に行うことで、
  /// 実際のカメラフレームレート(24〜60fps)全部を毎回変換するコストを避ける。
  private final class PreviewFrameEncoder: @unchecked Sendable {
    private let targetLongEdge: CGFloat
    private let minFrameInterval: CFTimeInterval
    private let context = CIContext()
    private let lock = NSLock()
    private var lastEmitTime: CFTimeInterval = 0

    init(targetLongEdge: CGFloat, minFrameInterval: CFTimeInterval) {
      self.targetLongEdge = targetLongEdge
      self.minFrameInterval = minFrameInterval
    }

    func encodeIfDue(_ sampleBuffer: CMSampleBuffer) -> Data? {
      let now = CACurrentMediaTime()
      lock.lock()
      guard now - lastEmitTime >= minFrameInterval else {
        lock.unlock()
        return nil
      }
      lastEmitTime = now
      lock.unlock()

      guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
      // カメラのライブ映像はHDRで届くことがあり、そのままJPEGエンコードしようとすると
      // CoreImageが自動でHDRゲインマップ生成を試みて
      // 「Cannot create a gainmap if the hdrImage is not a valid CIImage」という警告を
      // 大量に出す。プレビュー用途にHDRは不要なので、生成時点でSDRへトーンマップして回避する。
      let ciImage = CIImage(cvImageBuffer: imageBuffer, options: [.toneMapHDRtoSDR: true])
      let longEdge = max(ciImage.extent.width, ciImage.extent.height)
      guard longEdge > 0 else { return nil }
      let scale = targetLongEdge / longEdge
      let scaled =
        scale < 1
        ? ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : ciImage
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
      return context.jpegRepresentation(
        of: scaled, colorSpace: colorSpace,
        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.5])
    }
  }

  extension PeerCaptureCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
      _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
      from connection: AVCaptureConnection
    ) {
      guard let jpegData = previewEncoder.encodeIfDue(sampleBuffer) else { return }
      previewFramesContinuation.yield(jpegData)
    }
  }

  extension PeerCaptureCameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
      _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
      error: Error?
    ) {
      // `photo`(AVCapturePhoto)自体はSendableではないため、MainActorのTaskへ
      // 渡す前にこのnonisolatedコンテキスト内でDataへ変換しておく。
      let data = photo.fileDataRepresentation()
      Task { @MainActor in
        guard let continuation = self.captureContinuation else { return }
        self.captureContinuation = nil
        if let error {
          continuation.resume(throwing: CaptureError.captureFailed(error))
          return
        }
        guard let data else {
          continuation.resume(throwing: CaptureError.missingFileRepresentation)
          return
        }
        continuation.resume(returning: data)
      }
    }
  }
#endif
