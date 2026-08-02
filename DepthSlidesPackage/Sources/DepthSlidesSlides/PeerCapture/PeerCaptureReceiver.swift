#if os(macOS)
  import Foundation
  import Network
  import Observation

  /// Mac側: Bonjourサービスを広告し、iPhoneからの写真転送を受け付ける。
  @Observable
  @MainActor
  final class PeerCaptureReceiver {
    enum State: Equatable {
      case idle
      case listening
      case receiving
      case received(Data)
      case failed(String)
    }

    private(set) var state: State = .idle
    private var listener: NWListener?

    func start() {
      guard listener == nil else { return }
      state = .listening

      let params = NWParameters.tcp
      params.includePeerToPeer = true

      let newListener: NWListener
      do {
        newListener = try NWListener(using: params)
      } catch {
        state = .failed("リスナーの作成に失敗: \(error.localizedDescription)")
        return
      }
      newListener.service = NWListener.Service(type: PeerCaptureProtocol.bonjourServiceType)
      newListener.newConnectionHandler = { [weak self] connection in
        Task { @MainActor in await self?.accept(connection) }
      }
      newListener.stateUpdateHandler = { [weak self] listenerState in
        Task { @MainActor in
          if case .failed(let error) = listenerState {
            self?.state = .failed("リスナーが失敗しました: \(error.localizedDescription)")
          }
        }
      }
      newListener.start(queue: .main)
      listener = newListener
    }

    func stop() {
      listener?.cancel()
      listener = nil
      state = .idle
    }

    /// 受信済みデータを取り込んだあとに呼び、次の撮影をまた受け付けられるようにする。
    func acknowledgeReceived() {
      if case .received = state {
        state = .listening
      }
    }

    private func accept(_ nwConnection: NWConnection) async {
      state = .receiving
      let connection = PeerCaptureConnection(connection: nwConnection)
      do {
        try await connection.start()
        let frame = try await connection.receiveFrame()
        guard frame.type == .heicPhoto else {
          throw PeerCaptureProtocol.FramingError.invalidMessageType
        }
        try await connection.sendFrame(type: .ack, payload: Data())
        await connection.cancel()
        state = .received(frame.payload)
      } catch {
        state = .failed("受信に失敗しました: \(error.localizedDescription)")
      }
    }
  }
#endif
