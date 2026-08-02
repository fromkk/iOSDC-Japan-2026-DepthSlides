import Foundation
import Network
import OSLog

private let logger = Logger(
  subsystem: "info.fromkk.DepthSlides", category: "PresentationSyncNetworkManager")

/// Bonjourで自分自身をadvertiseしつつ、常時他端末をbrowseして複数接続を維持する。
/// Mac/iPhoneどちらでも同じ動作(全端末が常にadvertiseとbrowseの両方を行う対称設計)。
/// `../Presentations`の`NetworkManager`(WiFi Aware版)をBonjour/TCP向けに移植したもの。
actor PresentationSyncNetworkManager {
  static let bonjourServiceType = "_depthslides-sync._tcp"

  private let connectionManager: PresentationSyncConnectionManager
  private var listenerTask: Task<Void, Never>?
  private var browserTask: Task<Void, Never>?

  init(connectionManager: PresentationSyncConnectionManager) {
    self.connectionManager = connectionManager
  }

  func start() {
    guard listenerTask == nil else { return }
    listenerTask = Task { await self.listen() }
    browserTask = Task { await self.browse() }
  }

  func stop() {
    listenerTask?.cancel()
    browserTask?.cancel()
    listenerTask = nil
    browserTask = nil
  }

  private func makeParameters() -> NWParametersBuilder<
    Coder<PresentationSyncMessage, PresentationSyncMessage, NetworkJSONCoder>
  > {
    .parameters {
      Coder(
        receiving: PresentationSyncMessage.self, sending: PresentationSyncMessage.self,
        using: NetworkJSONCoder()
      ) {
        TCP()
      }
    }
  }

  private func listen() async {
    do {
      let listener = try NetworkListener(
        for: .bonjour(type: Self.bonjourServiceType, domain: nil),
        using: makeParameters()
      )
      try await listener.run { connection in
        await self.connectionManager.add(connection)
      }
    } catch {
      logger.error("listener failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func browse() async {
    do {
      // browseResultsのハンドラは変更のたび「現在の全端末」を渡してくる仕様のため、
      // 既に接続を試みたエンドポイントは無視しないと、他の端末が増減するたびに
      // 同じ相手へ何度も新規コネクションを張ってしまう。
      var attemptedIDs: Set<String> = []
      let browser = NetworkBrowser(for: .bonjour(Self.bonjourServiceType))
      try await browser.run { endpoints in
        for endpoint in endpoints where !attemptedIDs.contains(endpoint.id) {
          attemptedIDs.insert(endpoint.id)
          let connection = NetworkConnection(to: endpoint, using: self.makeParameters())
          await self.connectionManager.add(connection)
        }
      }
    } catch {
      logger.error("browser failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
