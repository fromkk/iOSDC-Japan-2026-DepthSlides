import AVFoundation
import Foundation

/// レンダリング済みバッファを `AVAudioEngine` で再生するプレイヤー（仕様書 §5 / §6.1）。
@MainActor
public final class ChimePlayer {
  /// iOS / tvOS / visionOS での `AVAudioSession` の扱い。
  public enum SessionPolicy: Sendable {
    /// 既定。他アプリの音楽を止めない（`.ambient` + `.mixWithOthers`）
    case ambient
    /// チャイムが主コンテンツのとき
    case playback
    /// 呼び出し側で AVAudioSession を管理する
    case none
  }

  /// §6.1: AVAudioPlayerNode のプール数（連打対応のラウンドロビン）
  private static let playerPoolSize = 4

  private let engine = AVAudioEngine()
  private var playerPool: [AVAudioPlayerNode] = []
  private var nextPlayerIndex = 0
  private var cache: [CacheKey: AVAudioPCMBuffer] = [:]
  private var observers: [NSObjectProtocol] = []
  private let sampleRate: Double
  private let sessionPolicy: SessionPolicy

  private struct CacheKey: Hashable {
    let sequence: ChimeSequence
    let voice: BarVoice
  }

  public init(sampleRate: Double = 48_000, sessionPolicy: SessionPolicy = .ambient) {
    self.sampleRate = sampleRate
    self.sessionPolicy = sessionPolicy
    observeSessionNotifications()
  }

  isolated deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  /// 音量 0...1
  public var volume: Float {
    get { engine.mainMixerNode.outputVolume }
    set { engine.mainMixerNode.outputVolume = min(max(newValue, 0), 1) }
  }

  /// 事前レンダリングしてキャッシュ。起動時に呼ぶと初回再生のもたつきが消える。
  public func preload(_ sequence: ChimeSequence, voice: BarVoice = .default) {
    _ = buffer(for: sequence, voice: voice)
  }

  /// 再生。連打しても前の音を切らずに重ねる（§6.1: 4本プールをラウンドロビン、
  /// 全部使用中なら最古を上書き）。
  public func play(_ sequence: ChimeSequence, voice: BarVoice = .default) {
    let buffer = buffer(for: sequence, voice: voice)
    guard ensureEngineRunning() else { return }
    let player = playerPool[nextPlayerIndex]
    nextPlayerIndex = (nextPlayerIndex + 1) % playerPool.count
    player.stop()
    player.scheduleBuffer(buffer, completionHandler: nil)
    player.play()
  }

  public func stop() {
    for player in playerPool {
      player.stop()
    }
    engine.pause()
  }

  // MARK: - Private

  private func buffer(for sequence: ChimeSequence, voice: BarVoice) -> AVAudioPCMBuffer {
    let key = CacheKey(sequence: sequence, voice: voice)
    if let cached = cache[key] {
      return cached
    }
    let buffer = AVAudioPCMBuffer.chime(sequence, voice: voice, sampleRate: sampleRate)
    cache[key] = buffer
    return buffer
  }

  /// §6.1: エンジンは初回 play で lazy start
  private func ensureEngineRunning() -> Bool {
    if playerPool.isEmpty {
      configureSession()
      guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
        return false
      }
      for _ in 0..<Self.playerPoolSize {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        playerPool.append(player)
      }
      engine.prepare()
    }
    if !engine.isRunning {
      do {
        try engine.start()
      } catch {
        return false
      }
    }
    return true
  }

  private func configureSession() {
    #if os(iOS) || os(tvOS) || os(visionOS)
      let session = AVAudioSession.sharedInstance()
      do {
        switch sessionPolicy {
        case .ambient:
          try session.setCategory(.ambient, options: [.mixWithOthers])
        case .playback:
          try session.setCategory(.playback)
        case .none:
          return
        }
        try session.setActive(true)
      } catch {
        // セッション設定に失敗しても再生自体は試みる
      }
    #endif
  }

  /// §6.1: 中断復帰・経路変更時に engine を再起動する
  private func observeSessionNotifications() {
    #if os(iOS) || os(tvOS) || os(visionOS)
      let center = NotificationCenter.default
      observers.append(
        center.addObserver(
          forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
          let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
          MainActor.assumeIsolated {
            guard let self,
              let rawType,
              AVAudioSession.InterruptionType(rawValue: rawType) == .ended
            else { return }
            self.restartEngineIfNeeded()
          }
        })
      observers.append(
        center.addObserver(
          forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated {
            self?.restartEngineIfNeeded()
          }
        })
    #endif
  }

  private func restartEngineIfNeeded() {
    guard !playerPool.isEmpty, !engine.isRunning else { return }
    try? engine.start()
  }
}
