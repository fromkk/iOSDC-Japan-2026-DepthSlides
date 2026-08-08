import Foundation

/// 音板1枚ぶんの物理パラメータ（仕様書 §5）。
public struct BarVoice: Sendable, Equatable, Hashable {
  /// §3.1: 合成するモード数（最大 5）
  public var modeCount: Int = 5
  /// §3.2: 打点の正規化位置 0...1（既定は板の中央）
  public var strikePosition: Double = 0.5
  /// §3.7: 打点ジッタ（±値、一様分布)
  public var strikeJitter: Double = 0.02
  /// §3.7: デチューン（±セント）
  public var detuneCents: Double = 1.5
  /// §3.7: 全体レベルのばらつき（±比率）
  public var levelJitter: Double = 0.06
  /// §3.3: マレットの接触時間による高域ロールオフのカットオフ [Hz]
  public var malletCutoff: Double = 3500
  /// §3.6: マレットノイズ（打撃の「コッ」）のレベル
  public var malletNoiseLevel: Double = 0.03
  /// §3.4: A4 (440 Hz) 基準の T60 [s]
  public var ringTime: Double = 4.5
  /// §3.5: アタック時間 [s]。無いとクリックノイズが乗る
  public var attackTime: Double = 0.0015

  public init() {}

  public static let `default` = BarVoice()

  /// 残響を詰めたアプリ内 UI 向け（§3.4）
  public static let short: BarVoice = {
    var voice = BarVoice()
    voice.ringTime = 2.2
    return voice
  }()

  /// 柔らかいマレット（§3.3 / §3.6）
  public static let soft: BarVoice = {
    var voice = BarVoice()
    voice.malletCutoff = 1800
    voice.malletNoiseLevel = 0.015
    return voice
  }()
}
