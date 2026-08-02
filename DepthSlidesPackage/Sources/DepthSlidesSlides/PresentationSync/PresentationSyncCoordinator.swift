import Foundation
import Observation
import SlideKit

/// `SlideIndexController`とネットワーク層を橋渡しする、アプリ全体でひとつだけ
/// 生成される調整役。プレゼン開始時に`start(attachingTo:)`を1回呼ぶと以後
/// 常時advertise+browseし続け、双方向のページ同期と(Feature B用の)ライブ
/// プレビューフレーム受信を提供する。
///
/// ページ送りのユーザー操作は`forward()`/`back()`を経由させる必要がある
/// （`SlideIndexController.forward()`/`back()`を呼び出し元が直接叩くと、
/// スライド内のPhase(段階表示)だけが進むケースを検知できず同期できないため）。
@MainActor
@Observable
public final class PresentationSyncCoordinator {
  @ObservationIgnored private let connectionManager = PresentationSyncConnectionManager()
  @ObservationIgnored private lazy var networkManager = PresentationSyncNetworkManager(
    connectionManager: connectionManager)
  @ObservationIgnored private lazy var previewFrameSender = PresentationSyncPreviewFrameSender(
    connectionManager: connectionManager)

  @ObservationIgnored private weak var slideIndexController: SlideIndexController?
  @ObservationIgnored private var messagesTask: Task<Void, Never>?
  @ObservationIgnored private var localEventsTask: Task<Void, Never>?

  /// 受信メッセージを`slideIndexController`へ適用している間だけtrue。
  /// 適用に`forward()`/`back()`/`move(to:)`を使う都合上、万一この適用中に
  /// 別経路で`forward()`/`back()`(このクラスの公開メソッド)が呼ばれても
  /// 二重ブロードキャストしないためのガード。
  @ObservationIgnored private var isApplyingRemoteChange = false

  /// 自分自身の識別子と送信連番。全端末が対称にadvertise+browseするため同じ相手と
  /// 複数コネクションが張られることがあり、`broadcast`で同一イベントが2回以上
  /// 届きうる。この(送信元, 連番)を使って受信側で重複を検出する。
  @ObservationIgnored private let localDeviceID = UUID()
  @ObservationIgnored private var nextSequence = 0
  @ObservationIgnored private var lastSeenSequence: [UUID: Int] = [:]

  /// Feature B: 直近に受信したプレビューフレーム。`@Observable`なので更新されると
  /// これを読んでいるSwiftUI Viewが自動的に再描画される。
  public private(set) var latestPreviewFrameData: Data?

  public init() {}

  public func start(attachingTo slideIndexController: SlideIndexController) {
    guard messagesTask == nil else { return }
    self.slideIndexController = slideIndexController

    messagesTask = Task { [weak self] in
      guard let self else { return }
      for await message in self.connectionManager.incomingMessages {
        await self.handle(message)
      }
    }
    localEventsTask = Task { [weak self] in
      guard let self else { return }
      for await event in self.connectionManager.localEvents {
        await self.handle(event)
      }
    }

    let networkManager = self.networkManager
    Task { await networkManager.start() }
  }

  public func stop() {
    messagesTask?.cancel()
    localEventsTask?.cancel()
    messagesTask = nil
    localEventsTask = nil

    let networkManager = self.networkManager
    let connectionManager = self.connectionManager
    Task {
      await networkManager.stop()
      await connectionManager.stop()
    }
  }

  /// スライド送り操作の入口。呼び出し元（`PresenterCommands`・`SlideNavigationView`等）は
  /// `slideIndexController.forward()`を直接呼ばず、必ずこちらを経由すること。
  @discardableResult
  public func forward() -> Bool {
    step(direction: .forward)
  }

  @discardableResult
  public func back() -> Bool {
    step(direction: .back)
  }

  @discardableResult
  private func step(direction: SlideStepDirection) -> Bool {
    guard let slideIndexController, !isApplyingRemoteChange else { return false }
    let didStep = direction == .forward ? slideIndexController.forward() : slideIndexController.back()
    guard didStep else { return false }
    let resultingIndex = slideIndexController.currentIndex
    let message = nextSlideIndexMessage(direction: direction, resultingIndex: resultingIndex)
    let connectionManager = self.connectionManager
    Task { await connectionManager.broadcast(message) }
    return true
  }

  private func nextSlideIndexMessage(direction: SlideStepDirection?, resultingIndex: Int)
    -> PresentationSyncMessage
  {
    defer { nextSequence += 1 }
    return .slideIndex(
      senderID: localDeviceID, sequence: nextSequence, direction: direction,
      resultingIndex: resultingIndex)
  }

  /// Feature B: iPhone側から呼ぶ。同一コネクション上にプレビューフレームを乗せる。
  public func sendPreviewFrame(_ jpegData: Data) {
    let sender = previewFrameSender
    Task { await sender.submit(jpegData) }
  }

  private func handle(_ message: PresentationSyncMessage) async {
    switch message {
    case .slideIndex(let senderID, let sequence, let direction, let resultingIndex):
      // 全端末が自分自身にもadvertise+browseしうる(Bonjourは自端末の広告も
      // browseで見えてしまう)ため、自分が送信したイベントが自分自身にエコーバック
      // することがある。それを二重適用しないよう、自分のsenderIDは無視する。
      guard senderID != localDeviceID else { return }

      // 全端末が対称にadvertise+browseするため同じ相手と複数コネクションが張られ、
      // `broadcast`されたイベントが2回以上届くことがある。(送信元, 連番)が既に見た値
      // 以下なら重複/古いメッセージなので無視する。
      let lastSequence = lastSeenSequence[senderID] ?? -1
      guard sequence > lastSequence else { return }
      lastSeenSequence[senderID] = sequence

      guard let slideIndexController else { return }
      isApplyingRemoteChange = true
      if let direction, slideIndexController.currentIndex == resultingIndex {
        // 送信側と自分のindexが一致 = Phaseだけが進んだ相対ステップの可能性が高いので、
        // 同じ相対操作を再生してPhaseまで揃える。
        _ = direction == .forward ? slideIndexController.forward() : slideIndexController.back()
      } else {
        // indexがズレている(実際にスライドが変わった/途中参加/取りこぼし)ので絶対位置へ。
        slideIndexController.move(to: resultingIndex)
      }
      isApplyingRemoteChange = false
    case .cameraPreviewFrame(let jpegData):
      latestPreviewFrameData = jpegData
    }
  }

  private func handle(_ event: PresentationSyncLocalEvent) async {
    switch event {
    case .connectionReady(let id):
      // 途中参加してきた端末がスライド0のまま止まらないよう、現在地を即送信する。
      guard let slideIndexController else { return }
      let message = nextSlideIndexMessage(
        direction: nil, resultingIndex: slideIndexController.currentIndex)
      await connectionManager.send(message, to: id)
    case .connectionLost:
      break
    }
  }
}
