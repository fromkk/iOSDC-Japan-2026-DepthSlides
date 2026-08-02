#if os(iOS)
  import Foundation
  import Network
  import Observation

  /// iPhone側: MacのBonjourサービスを探し、撮影済みHEICを1回だけ送信する。
  /// v1では最初に見つかった1台に自動接続する(複数Mac同時広告は対象外)。
  @Observable
  @MainActor
  final class PeerCaptureSender {
    enum State: Equatable {
      case idle
      case discovering
      case found(String)
      case sending
      case sent
      case failed(String)
    }

    private(set) var state: State = .idle
    private var browser: NWBrowser?

    func discoverAndSend(heicData: Data) async {
      state = .discovering

      let endpoint: NWEndpoint
      do {
        endpoint = try await discoverEndpoint()
      } catch {
        state = .failed("Macが見つかりませんでした: \(error.localizedDescription)")
        return
      }

      state = .found(displayName(for: endpoint))
      state = .sending

      let connection = PeerCaptureConnection.outgoing(to: endpoint)
      do {
        try await connection.start()
        try await connection.sendFrame(type: .heicPhoto, payload: heicData)
        let ack = try await connection.receiveFrame()
        guard ack.type == .ack else {
          throw PeerCaptureProtocol.FramingError.invalidMessageType
        }
        await connection.cancel()
        state = .sent
      } catch {
        state = .failed("送信に失敗しました: \(error.localizedDescription)")
      }
    }

    func cancel() {
      browser?.cancel()
      browser = nil
      state = .idle
    }

    private func discoverEndpoint() async throws -> NWEndpoint {
      let params = NWParameters.tcp
      params.includePeerToPeer = true
      let browser = NWBrowser(
        for: .bonjour(type: PeerCaptureProtocol.bonjourServiceType, domain: nil), using: params)
      self.browser = browser
      defer {
        browser.cancel()
        self.browser = nil
      }

      return try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<NWEndpoint, Error>) in
        let resumeGuard = PeerCaptureResumeGuard()
        browser.browseResultsChangedHandler = { results, _ in
          guard let first = results.first else { return }
          if resumeGuard.tryResume() { continuation.resume(returning: first.endpoint) }
        }
        browser.stateUpdateHandler = { browserState in
          if case .failed(let error) = browserState {
            if resumeGuard.tryResume() { continuation.resume(throwing: error) }
          }
        }
        browser.start(queue: .main)
      }
    }

    private func displayName(for endpoint: NWEndpoint) -> String {
      switch endpoint {
      case .service(let name, _, _, _):
        return name
      case .hostPort(let host, _):
        return "\(host)"
      default:
        return "不明な端末"
      }
    }
  }
#endif
