import Foundation

/// チャイムの音列（仕様書 §2 / §5）。
public struct ChimeSequence: Sendable, Equatable, Hashable {
  /// §2.1: 周波数列 [Hz]。純正律の実測値をそのまま持つ
  public var frequencies: [Double]
  /// §2.3: 音符間隔 [s]（4分音符 / BPM 110）
  public var noteInterval: TimeInterval
  /// §2.3: バッファ全長の上限 [s]
  public var maxDuration: TimeInterval
  /// §2.3: 最終音の T60 後に足すパディング [s]
  public var tailPadding: TimeInterval

  public init(
    frequencies: [Double],
    noteInterval: TimeInterval = 0.5454,
    maxDuration: TimeInterval = 10.0,
    tailPadding: TimeInterval = 0.3
  ) {
    self.frequencies = frequencies
    self.noteInterval = noteInterval
    self.maxDuration = maxDuration
    self.tailPadding = tailPadding
  }

  // §2.2: 純正律プリセット（4:5:6:8 の純正長三和音）

  /// アナウンス前（上り4音）: ピンポンパンポーン
  public static let ascending4 = ChimeSequence(frequencies: [440, 550, 660, 880])
  /// アナウンス後（下り4音）
  public static let descending4 = ChimeSequence(frequencies: [880, 660, 550, 440])
  /// 上り5音
  public static let ascending5 = ChimeSequence(frequencies: [330, 440, 550, 660, 880])
  /// 下り5音
  public static let descending5 = ChimeSequence(frequencies: [880, 660, 550, 440, 330])

  /// §2.1: 平均律（A/B比較用）。C#5 = 554.365 Hz が純正律より約 14 セント高い
  public static let equalTemperedAscending4 = ChimeSequence(frequencies: [
    440, 554.365, 659.255, 880,
  ])

  /// §2.3: 音符間隔を factor 倍（1.6 で放送設備の「ゆっくり」相当）
  public func slowed(by factor: Double) -> ChimeSequence {
    var sequence = self
    sequence.noteInterval = noteInterval * factor
    return sequence
  }

  /// 全体を ratio 倍の周波数へ移調（純正律の比を保つ）
  public func transposed(ratio: Double) -> ChimeSequence {
    var sequence = self
    sequence.frequencies = frequencies.map { $0 * ratio }
    return sequence
  }

  /// 反転（上り ⇄ 下り）
  public var reversed: ChimeSequence {
    var sequence = self
    sequence.frequencies = frequencies.reversed()
    return sequence
  }
}
