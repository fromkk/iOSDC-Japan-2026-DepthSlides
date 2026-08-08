import AVFoundation
import Observation
import OSLog

private let logger = Logger(subsystem: "info.fromkk.DepthSlides", category: "UVCCameraSession")

/// f値スライド用: 内蔵カメラ、または外部UVCカメラ（キャプチャデバイスやUVC出力の
/// ミラーレス機など）・Continuity Camera経由のiPhoneのライブ映像を
/// モニターするためだけのセッション。Depth合成や撮影機能は持たない。
@MainActor
@Observable
final class UVCCameraSession: NSObject {
  /// プレビューに使う入力ソース。
  enum Source: Hashable {
    /// Mac内蔵（FaceTime）カメラ。
    case builtIn
    /// 外部UVCカメラまたはContinuity Camera。
    case external
  }

  let session = AVCaptureSession()

  /// 現在接続されているデバイスから選択可能なソース。
  private(set) var availableSources: Set<Source> = []
  /// 表示中のソース。`nil` は非表示（セッション停止）。
  private(set) var selectedSource: Source?

  @ObservationIgnored private var isMonitoring = false
  @ObservationIgnored private var currentInput: AVCaptureDeviceInput?
  @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []
  // AVCaptureSessionのstartRunning/stopRunningはブロッキング呼び出しのためバックグラウンド
  // スレッドで呼ぶ必要があるが、Swift 6の並行性検査はMainActor隔離プロパティを
  // 別Taskへ直接「送る」ことを警告する。開始/停止呼び出し自体はドキュメント上
  // どのスレッドからでも安全なため、@unchecked Sendableな小さな箱に包んで送る。
  // start/stopは呼ばれた順序で確実に実行される必要がある(スライドを行き来する際、
  // 直前のstartがまだ実行されないうちに次のstopが呼ばれると、独立した
  // `Task.detached`同士では実行順序が保証されずstopが先に空振りし、後から
  // startだけが実行されてセッションが動きっぱなしになり、カメラデバイスを
  // 掴んだまま解放されなくなる。そのため直列キューで順序を保証する)。
  @ObservationIgnored private lazy var sessionBox = SessionRunner(session: session)

  /// 何度呼ばれても安全。スライドの表示/非表示が短時間に繰り返されても
  /// 監視の二重登録やstart/stopの呼び忘れが起きないようにする。
  func startMonitoring() {
    guard !isMonitoring else { return }
    isMonitoring = true
    observeDeviceNotifications()
    refreshDevices()
  }

  func stopMonitoring() {
    guard isMonitoring else { return }
    isMonitoring = false
    notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    notificationTokens = []
    // 次にこのスライドへ戻ってきたときに同じ物理デバイスへすぐ再接続できるよう、
    // 停止と同時に入力も外してデバイスの占有を手放す。
    removeCurrentInput()
    availableSources = []
    selectedSource = nil
    stopRunning()
  }

  /// 表示するソースを切り替える。`nil` で非表示（セッション停止）。
  func select(_ source: Source?) {
    selectedSource = source
    applySelection()
  }

  private func observeDeviceNotifications() {
    let center = NotificationCenter.default
    let connected = center.addObserver(
      forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.refreshDevices() }
    }
    let disconnected = center.addObserver(
      forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.refreshDevices() }
    }
    notificationTokens = [connected, disconnected]
  }

  private func refreshDevices() {
    var sources: Set<Source> = []
    if device(for: .builtIn) != nil { sources.insert(.builtIn) }
    if device(for: .external) != nil { sources.insert(.external) }
    logger.log(
      "refreshDevices: builtIn=\(sources.contains(.builtIn), privacy: .public) external=\(sources.contains(.external), privacy: .public)"
    )

    availableSources = sources
    if let selectedSource, !sources.contains(selectedSource) {
      self.selectedSource = nil
    }
    applySelection()
  }

  private func device(for source: Source) -> AVCaptureDevice? {
    let deviceTypes: [AVCaptureDevice.DeviceType] =
      switch source {
      case .builtIn: [.builtInWideAngleCamera]
      case .external: [.external, .continuityCamera]
      }
    return AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .unspecified
    ).devices.first
  }

  /// `selectedSource`に合わせて入力の付け替えとセッションの起動/停止を行う。
  /// 非表示中はカメラを掴まない（インジケータランプを点けない）よう、
  /// 選択が外れたら入力を外してセッションも止める。
  private func applySelection() {
    guard let selectedSource, let device = device(for: selectedSource) else {
      removeCurrentInput()
      stopRunning()
      return
    }

    if currentInput?.device == device {
      startRunning()
      return
    }

    do {
      try attach(device)
      startRunning()
    } catch {
      logger.error("attach(device:) failed: \(error.localizedDescription, privacy: .public)")
      self.selectedSource = nil
      removeCurrentInput()
      stopRunning()
    }
  }

  private func attach(_ device: AVCaptureDevice) throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }

    removeCurrentInput()

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else { return }
    session.addInput(input)
    currentInput = input
  }

  private func removeCurrentInput() {
    guard let currentInput else { return }
    session.beginConfiguration()
    session.removeInput(currentInput)
    session.commitConfiguration()
    self.currentInput = nil
  }

  private func startRunning() {
    sessionBox.start()
  }

  private func stopRunning() {
    sessionBox.stop()
  }
}

/// `AVCaptureSession`はSendableではないため、start/stopをバックグラウンドの
/// 直列キューから安全に呼べるよう`@unchecked Sendable`な箱に包む。
/// (`AVCaptureSession.startRunning()/stopRunning()`はどのスレッドから呼んでも
/// 安全、というのはApple公式ドキュメントの記載どおり)
///
/// `start()`/`stop()`はどちらも呼び出し元(MainActor)から見て発行した順序どおりに
/// 実行される必要がある。個別の`Task.detached`に投げると、Swift Concurrencyの
/// スケジューリングは呼び出し順序を保証しないため、直後のstopがstartを追い越して
/// 空振りし、あとから残ったstartだけが実行されてセッションが動きっぱなしになる
/// (=カメラデバイスが解放されない)ことがある。直列の`DispatchQueue`を使うことで
/// FIFOの実行順序を保証する。
private final class SessionRunner: @unchecked Sendable {
  private let session: AVCaptureSession
  private let queue = DispatchQueue(label: "info.fromkk.DepthSlides.uvccamera.session")

  init(session: AVCaptureSession) {
    self.session = session
  }

  func start() {
    queue.async { [session] in
      guard !session.isRunning else { return }
      session.startRunning()
    }
  }

  func stop() {
    queue.async { [session] in
      guard session.isRunning else { return }
      session.stopRunning()
    }
  }
}
