import Foundation

/// iPhone(送信側)とMac(受信側)の間で、撮影したHEICを1回だけ転送するための
/// 最小限のワイヤフォーマット。複数メッセージ種別を多重化する必要が無い
/// (1接続につき写真1枚を送ってackを待ちクローズするだけ)ため、
/// `NWProtocolFramer` は使わず、生の `NWConnection.send`/`receive` の上に
/// 手動の長さプレフィックス方式を実装する。
enum PeerCaptureProtocol {
  static let bonjourServiceType = "_depthslides-cap._tcp"

  /// 想定される最大ペイロードサイズ(HEICは通常数MB〜十数MB程度)。
  /// 壊れた/悪意あるフレームでメモリを食い潰さないための安全弁。
  static let maxPayloadBytes = 64 * 1024 * 1024

  enum MessageType: UInt8 {
    case heicPhoto = 1
    case ack = 2
  }

  enum FramingError: Error {
    case payloadTooLarge
    case invalidMessageType
    case connectionClosed
  }

  /// `[1バイト type][4バイト BE 長さ][payload]`
  static func encodeFrame(type: MessageType, payload: Data) -> Data {
    var frame = Data(capacity: 5 + payload.count)
    frame.append(type.rawValue)
    var length = UInt32(payload.count).bigEndian
    withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
    frame.append(payload)
    return frame
  }
}

/// `withCheckedThrowingContinuation`をNetwork frameworkの複数コールバック
/// (stateUpdateHandler / browseResultsChangedHandler等)から一度だけresumeするための
/// 小さな排他制御ヘルパー。Swift 6の厳格な並行性チェック下では、`@Sendable`な
/// コールバッククロージャからローカルの`var`を直接書き換えられないため使う。
final class PeerCaptureResumeGuard: @unchecked Sendable {
  private var didResume = false
  private let lock = NSLock()

  /// 最初の1回だけtrueを返す。以降の呼び出しは全てfalse。
  func tryResume() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !didResume else { return false }
    didResume = true
    return true
  }
}
