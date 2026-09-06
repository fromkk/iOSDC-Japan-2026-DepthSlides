import AVFoundation
import SwiftUI

/// スライドの中で無音・コントロールなしで動画をループ再生するビュー。
///
/// `VideoPlayer` はホバーで再生コントロールが出てしまうので、スクリーン
/// レコーディングを「動くスクリーンショット」として置きたい用途では
/// `AVPlayerLayer` を直接使う。ループは `AVPlayerLooper` に任せる。
struct LoopingVideoView: View {
  let url: URL

  var body: some View {
    PlayerLayerView(url: url)
  }
}

#if canImport(UIKit)
  private struct PlayerLayerView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> LoopingPlayerCoordinator {
      LoopingPlayerCoordinator(url: url)
    }

    func makeUIView(context: Context) -> PlayerHostView {
      let view = PlayerHostView()
      view.playerLayer.player = context.coordinator.player
      view.playerLayer.videoGravity = .resizeAspect
      context.coordinator.play()
      return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {}
  }

  final class PlayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
  }
#else
  private struct PlayerLayerView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> LoopingPlayerCoordinator {
      LoopingPlayerCoordinator(url: url)
    }

    func makeNSView(context: Context) -> NSView {
      let view = NSView()
      let playerLayer = AVPlayerLayer(player: context.coordinator.player)
      playerLayer.videoGravity = .resizeAspect
      // レイヤーホスティングにするので、layer を差し替えてから wantsLayer を立てる。
      // 逆順だと AppKit が自前のレイヤーで上書きしてしまう。
      view.layer = playerLayer
      view.wantsLayer = true
      context.coordinator.play()
      return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
  }
#endif

/// `AVPlayerLooper` は保持しておかないとループが止まるので、Coordinator に持たせる。
@MainActor
final class LoopingPlayerCoordinator {
  let player: AVQueuePlayer
  private let looper: AVPlayerLooper

  init(url: URL) {
    let item = AVPlayerItem(url: url)
    let player = AVQueuePlayer()
    player.isMuted = true
    self.looper = AVPlayerLooper(player: player, templateItem: item)
    self.player = player
  }

  func play() {
    player.play()
  }
}
