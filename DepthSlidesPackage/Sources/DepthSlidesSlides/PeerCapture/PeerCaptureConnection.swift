import Foundation
import Network

/// `NWConnection` を包み、`PeerCaptureProtocol` のフレーム送受信をasync APIとして
/// 提供する。iOS送信側(`PeerCaptureSender`)・macOS受信側(`PeerCaptureReceiver`)の
/// 両方から同じロジックを使う。
actor PeerCaptureConnection {
  private let connection: NWConnection

  init(connection: NWConnection) {
    self.connection = connection
  }

  /// `NWBrowser`のBonjour発見結果(`NWEndpoint`)へそのまま接続する。
  static func outgoing(to endpoint: NWEndpoint) -> PeerCaptureConnection {
    let params = NWParameters.tcp
    params.includePeerToPeer = true
    return PeerCaptureConnection(connection: NWConnection(to: endpoint, using: params))
  }

  func start() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      let resumeGuard = PeerCaptureResumeGuard()
      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          if resumeGuard.tryResume() { continuation.resume() }
        case .failed(let error):
          if resumeGuard.tryResume() { continuation.resume(throwing: error) }
        case .cancelled:
          if resumeGuard.tryResume() {
            continuation.resume(throwing: PeerCaptureProtocol.FramingError.connectionClosed)
          }
        default:
          break
        }
      }
      connection.start(queue: .main)
    }
  }

  func sendFrame(type: PeerCaptureProtocol.MessageType, payload: Data) async throws {
    let frame = PeerCaptureProtocol.encodeFrame(type: type, payload: payload)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      connection.send(
        content: frame,
        completion: .contentProcessed { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        })
    }
  }

  func receiveFrame() async throws -> (type: PeerCaptureProtocol.MessageType, payload: Data) {
    let header = try await receiveExactly(5)
    guard let type = PeerCaptureProtocol.MessageType(rawValue: header[header.startIndex]) else {
      throw PeerCaptureProtocol.FramingError.invalidMessageType
    }
    let length = Int(decodeUInt32BE(header.dropFirst()))
    guard length <= PeerCaptureProtocol.maxPayloadBytes else {
      throw PeerCaptureProtocol.FramingError.payloadTooLarge
    }
    let payload = length == 0 ? Data() : try await receiveExactly(length)
    return (type, payload)
  }

  func cancel() {
    connection.cancel()
  }

  private func receiveExactly(_ count: Int) async throws -> Data {
    guard count <= PeerCaptureProtocol.maxPayloadBytes else {
      throw PeerCaptureProtocol.FramingError.payloadTooLarge
    }
    return try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Data, Error>) in
      connection.receive(minimumIncompleteLength: count, maximumLength: count) {
        data, _, _, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let data, data.count == count else {
          continuation.resume(throwing: PeerCaptureProtocol.FramingError.connectionClosed)
          return
        }
        continuation.resume(returning: data)
      }
    }
  }

  private func decodeUInt32BE(_ bytes: some Sequence<UInt8>) -> UInt32 {
    var value: UInt32 = 0
    for byte in bytes {
      value = (value << 8) | UInt32(byte)
    }
    return value
  }
}
