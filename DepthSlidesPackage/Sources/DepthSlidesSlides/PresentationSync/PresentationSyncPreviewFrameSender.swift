import Foundation

/// 「最新のフレームだけを送る」バックプレッシャー制御。送信中に新しいフレームが
/// 来たら古い方は捨てるので、回線が細くてもレイテンシが際限なく積み上がらない。
actor PresentationSyncPreviewFrameSender {
  private let connectionManager: PresentationSyncConnectionManager
  private var pendingFrame: Data?
  private var isSending = false

  init(connectionManager: PresentationSyncConnectionManager) {
    self.connectionManager = connectionManager
  }

  func submit(_ jpegData: Data) {
    pendingFrame = jpegData
    guard !isSending else { return }
    drainNext()
  }

  private func drainNext() {
    guard let next = pendingFrame else {
      isSending = false
      return
    }
    pendingFrame = nil
    isSending = true
    Task {
      await connectionManager.broadcast(.cameraPreviewFrame(jpegData: next))
      drainNext()
    }
  }
}
