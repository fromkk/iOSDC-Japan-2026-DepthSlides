import Foundation
import Network
import OSLog

typealias PresentationSyncConnection = NetworkConnection<
  Coder<PresentationSyncMessage, PresentationSyncMessage, NetworkJSONCoder>
>
typealias PresentationSyncConnectionID = String

enum PresentationSyncLocalEvent: Sendable {
  case connectionReady(PresentationSyncConnectionID)
  case connectionLost(PresentationSyncConnectionID)
}

private let logger = Logger(
  subsystem: "info.fromkk.DepthSlides", category: "PresentationSyncConnectionManager")

/// 複数の`PresentationSyncConnection`(Mac・iPhone等、複数台になりうる)を管理し、
/// 全接続への一斉送信(`broadcast`)と、受信メッセージの一本化されたストリームを提供する。
/// `../Presentations`の`ConnectionManager`(WiFi Aware版)と同じ役割をBonjour/TCP向けに移植したもの。
actor PresentationSyncConnectionManager {
  private var connections: [PresentationSyncConnectionID: PresentationSyncConnection] = [:]
  private var receiverTasks: [PresentationSyncConnectionID: Task<Void, Never>] = [:]

  let localEvents: AsyncStream<PresentationSyncLocalEvent>
  private let localEventsContinuation: AsyncStream<PresentationSyncLocalEvent>.Continuation

  let incomingMessages: AsyncStream<PresentationSyncMessage>
  private let incomingMessagesContinuation: AsyncStream<PresentationSyncMessage>.Continuation

  init() {
    (localEvents, localEventsContinuation) = AsyncStream.makeStream(of: PresentationSyncLocalEvent.self)
    (incomingMessages, incomingMessagesContinuation) = AsyncStream.makeStream(
      of: PresentationSyncMessage.self)
  }

  func add(_ connection: PresentationSyncConnection) {
    let id = connection.id
    guard receiverTasks[id] == nil else { return }
    logger.info("add connection: \(id, privacy: .public)")
    receiverTasks[id] = setupReceiver(connection)
    setupStateUpdateHandler(connection)
  }

  func broadcast(_ message: PresentationSyncMessage) async {
    for connection in connections.values {
      do {
        try await connection.send(message)
      } catch {
        logger.error("broadcast failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  func send(_ message: PresentationSyncMessage, to id: PresentationSyncConnectionID) async {
    guard let connection = connections[id] else { return }
    do {
      try await connection.send(message)
    } catch {
      logger.error("send(to:) failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func stop() {
    for task in receiverTasks.values { task.cancel() }
    receiverTasks.removeAll()
    connections.removeAll()
  }

  private func setupReceiver(_ connection: PresentationSyncConnection) -> Task<Void, Never> {
    Task {
      do {
        for try await (message, _) in connection.messages {
          incomingMessagesContinuation.yield(message)
        }
      } catch {
        logger.error("receive loop ended: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func setupStateUpdateHandler(_ connection: PresentationSyncConnection) {
    let id = connection.id
    connection.onStateUpdate { [weak self] connection, state in
      guard let self else { return }
      switch state {
      case .ready:
        Task { await self.markReady(connection) }
      case .failed, .cancelled:
        Task { await self.markLost(id) }
      default:
        break
      }
    }
  }

  private func markReady(_ connection: PresentationSyncConnection) {
    connections[connection.id] = connection
    localEventsContinuation.yield(.connectionReady(connection.id))
  }

  private func markLost(_ id: PresentationSyncConnectionID) {
    connections.removeValue(forKey: id)
    receiverTasks.removeValue(forKey: id)?.cancel()
    localEventsContinuation.yield(.connectionLost(id))
  }

  deinit {
    localEventsContinuation.finish()
    incomingMessagesContinuation.finish()
  }
}
