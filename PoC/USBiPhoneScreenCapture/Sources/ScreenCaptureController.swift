import AVFoundation
import Combine
import os.log

private let logger = Logger(
  subsystem: "info.fromkk.poc.USBiPhoneScreenCapture", category: "capture")

@MainActor
final class ScreenCaptureController: NSObject, ObservableObject {
  @Published var devices: [AVCaptureDevice] = []
  @Published var selectedDeviceID: String?
  @Published var statusMessage: String = "未起動"
  @Published var isRunning = false
  @Published var lastPhotoURL: URL?

  let session = AVCaptureSession()
  let photoOutput = AVCapturePhotoOutput()
  private var currentInput: AVCaptureDeviceInput?
  private var notificationTokens: [NSObjectProtocol] = []

  override init() {
    super.init()
    observeDeviceNotifications()
    refreshDevices()
  }

  deinit {
    notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
  }

  private func observeDeviceNotifications() {
    let center = NotificationCenter.default
    let connected = center.addObserver(
      forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.refreshDevices() }
    }
    let disconnected = center.addObserver(
      forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.refreshDevices() }
    }
    notificationTokens = [connected, disconnected]
  }

  // iPhoneはmacOS Tahoe以降、Continuity Camera経由のカメラ映像としてのみ
  // AVCaptureDeviceに現れる（画面ミラーではなくレンズ映像）。
  func refreshDevices() {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.continuityCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    devices = discovery.devices
    logger.log(
      "refreshDevices(.continuityCamera+.external/.video): count=\(self.devices.count, privacy: .public)"
    )
    for device in devices {
      logger.log(
        "  device: name=\(device.localizedName, privacy: .public) deviceType=\(device.deviceType.rawValue, privacy: .public) transportType=\(device.transportType, privacy: .public) uniqueID=\(device.uniqueID, privacy: .public)"
      )
    }

    if let selectedDeviceID, devices.contains(where: { $0.uniqueID == selectedDeviceID }) {
      return
    }
    selectedDeviceID = devices.first?.uniqueID
  }

  func requestAccessAndStart() {
    logger.log(
      "requestAccessAndStart: current authStatus=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue, privacy: .public)"
    )
    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      Task { @MainActor in
        guard let self else { return }
        logger.log("requestAccess(.video) granted=\(granted, privacy: .public)")
        if granted {
          self.start()
        } else {
          self.statusMessage = "カメラアクセスが拒否されました（システム設定を確認してください）"
        }
      }
    }
  }

  func start() {
    guard let selectedDeviceID,
      let device = devices.first(where: { $0.uniqueID == selectedDeviceID })
    else {
      statusMessage = "デバイスが見つかりません"
      return
    }

    session.beginConfiguration()
    if let currentInput {
      session.removeInput(currentInput)
      self.currentInput = nil
    }
    do {
      let input = try AVCaptureDeviceInput(device: device)
      if session.canAddInput(input) {
        session.addInput(input)
        currentInput = input
      } else {
        statusMessage = "セッションに入力を追加できませんでした"
        session.commitConfiguration()
        return
      }
    } catch {
      statusMessage = "入力の作成に失敗: \(error.localizedDescription)"
      session.commitConfiguration()
      return
    }
    if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
    }
    session.commitConfiguration()

    session.startRunning()

    // 検証結果: AVCapturePhotoOutput.isDepthDataDeliverySupported / isDepthDataDeliveryEnabled,
    // AVCaptureDevice.activeFormat.supportedDepthDataFormats, AVCapturePhoto.depthData は
    // いずれもmacOS SDKヘッダーで API_UNAVAILABLE(macos) と明記されておりビルドが通らない
    // （ios/macCatalyst/tvosのみ対応）。Continuity Camera云々ではなく、macOS上のAVFoundationでは
    // そもそもDepth Data Deliveryの経路自体が存在しない。
    logger.log(
      "photoOutput.availablePhotoCodecTypes=\(self.photoOutput.availablePhotoCodecTypes.map(\.rawValue), privacy: .public)"
    )

    isRunning = true
    statusMessage = "キャプチャ中: \(device.localizedName)"
    logger.log(
      "start: capturing \(device.localizedName, privacy: .public), session.isRunning=\(self.session.isRunning, privacy: .public)"
    )
  }

  func stop() {
    session.stopRunning()
    isRunning = false
    statusMessage = "停止しました"
  }

  func capturePhoto() {
    guard isRunning else { return }
    let settings: AVCapturePhotoSettings
    if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
      settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
    } else {
      settings = AVCapturePhotoSettings()
    }
    // NOTE: isDepthDataDeliveryEnabled はmacOSでは使えない（API_UNAVAILABLE(macos)）ため設定しない。
    photoOutput.capturePhoto(with: settings, delegate: self)
  }
}

extension ScreenCaptureController: AVCapturePhotoCaptureDelegate {
  nonisolated func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let error {
      logger.error("capturePhoto error: \(error.localizedDescription, privacy: .public)")
      return
    }
    // NOTE: photo.depthData もmacOSでは使えない（API_UNAVAILABLE(macos)）ため参照しない。
    guard let data = photo.fileDataRepresentation() else {
      logger.error("fileDataRepresentation failed")
      return
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "poc-capture-\(Int(Date().timeIntervalSince1970)).heic")
    do {
      try data.write(to: url)
      logger.log(
        "saved photo to \(url.path, privacy: .public), size=\(data.count, privacy: .public) bytes"
      )
      Task { @MainActor in
        self.lastPhotoURL = url
        self.statusMessage = "撮影完了 (\(url.lastPathComponent))"
      }
    } catch {
      logger.error("failed writing photo: \(error.localizedDescription, privacy: .public)")
    }
  }
}
