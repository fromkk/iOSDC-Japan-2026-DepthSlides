#if os(iOS)
  import AVFoundation
  import CoreImage
  import Foundation

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
    private let previewEncoder = PreviewFrameEncoder(targetLongEdge: 480, minFrameInterval: 1.0 / 15.0)

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
      guard
        let device = discovery.devices.first(where: {
          !$0.activeFormat.supportedDepthDataFormats.isEmpty
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

      let data = try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Data, Error>) in
        captureContinuation = continuation
        photoOutput.capturePhoto(with: settings, delegate: self)
      }

      guard EmbeddedDepthExtractor.hasEmbeddedDepth(in: data) else {
        throw CaptureError.depthNotEmbedded
      }
      return data
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
      let ciImage = CIImage(cvImageBuffer: imageBuffer)
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
