import Foundation

/// モーダル合成によるディナーチャイムのオフラインレンダラ（仕様書 §3 / §4 / §6.3）。
/// AVFoundation に依存しない純粋関数のみで構成する。
public enum ChimeRenderer {
  /// §3.1: エイリアシング防止。fₙ > sampleRate × この比率のモードはスキップ
  static let aliasingLimitRatio = 0.45
  /// §3.3: 撃力励振 → 変位振幅は 1/ω に比例
  static let displacementExponent = -1.0
  /// §3.4: T60₁ のクランプ範囲 [s]
  static let t60Range = 0.5...9.0
  /// §3.4: 高次モードの減衰指数（T60ₙ = T60₁ · rₙ^この値）
  static let modalDecayExponent = -0.7
  /// §3.5: env がこの値を下回ったフレーム以降はループを打ち切る
  static let envelopeFloor = 1e-5
  /// §3.6: マレットノイズの減衰時定数 [s]
  static let malletNoiseDecay = 0.004
  /// §3.6: マレットノイズの付加区間 [s]
  static let malletNoiseDuration = 0.020
  /// §3.6: マレットノイズのバンドパス中心周波数 [Hz]
  static let malletNoiseCenter = 4000.0
  /// §3.6: マレットノイズのバンドパス Q
  static let malletNoiseQ = 1.2
  /// §4: ピーク正規化の目標値（約 −1 dBFS）
  static let targetPeak = 0.89
  /// §2.3: 末尾の cosine フェードアウト長 [s]
  static let tailFadeDuration = 0.060
  /// §6.3: 各音のレンダリング長 = T60 × この係数
  static let noteLengthFactor = 1.2
  /// §3.4: T60 の基準周波数 [Hz]（A4）
  static let referenceFrequency = 440.0

  /// モノラル PCM を生成する。内部演算は `Double`、出力は `Float`（§4）。
  /// 同一 seed なら常にビット一致する出力になる（§3.7）。
  public static func renderMono(
    _ sequence: ChimeSequence,
    voice: BarVoice = .default,
    sampleRate: Double = 48_000,
    seed: UInt64 = 0x9E37_79B9_7F4A_7C15
  ) -> [Float] {
    var rng = SplitMix64(seed: seed)

    // §2.3: バッファ全長 = max_i(onset_i + T60₁(f_i)) + tailPadding、maxDuration でクランプ
    var totalDuration = 0.0
    for (i, f0) in sequence.frequencies.enumerated() {
      let onset = Double(i) * sequence.noteInterval
      totalDuration = max(totalDuration, onset + fundamentalT60(ringTime: voice.ringTime, f0: f0))
    }
    totalDuration = min(totalDuration + sequence.tailPadding, sequence.maxDuration)
    let totalFrames = Int(totalDuration * sampleRate)
    guard totalFrames > 0 else { return [] }

    var out = [Double](repeating: 0, count: totalFrames)
    let modeCount = min(voice.modeCount, FreeFreeBar.betaL.count)

    for (i, f0) in sequence.frequencies.enumerated() {
      let onset = Int(Double(i) * sequence.noteInterval * sampleRate)
      guard onset < totalFrames else { continue }

      // §3.7: 1打ごとのばらつき
      let x = voice.strikePosition
        + Double.random(in: -voice.strikeJitter...voice.strikeJitter, using: &rng)
      let detune = pow(2, Double.random(in: -voice.detuneCents...voice.detuneCents, using: &rng) / 1200)
      let gain = 1 + Double.random(in: -voice.levelJitter...voice.levelJitter, using: &rng)

      let t601 = fundamentalT60(ringTime: voice.ringTime, f0: f0)

      for m in 0..<modeCount {
        let r = FreeFreeBar.ratios[m]
        let f = f0 * r * detune
        guard f < sampleRate * aliasingLimitRatio else { continue }

        // §3.3: モード振幅
        let amp = FreeFreeBar.shape(mode: m, at: x)
          * pow(r, displacementExponent)
          * exp(-pow(f / voice.malletCutoff, 2))
          * gain
        // §3.4: 減衰
        let t60 = t601 * pow(r, modalDecayExponent)
        let decayRate = log(1000.0) / t60
        let omega = 2 * .pi * f / sampleRate

        let length = min(Int(t60 * noteLengthFactor * sampleRate), totalFrames - onset)
        for k in 0..<length {
          let t = Double(k) / sampleRate
          // §3.5: エンベロープ
          let decayEnv = exp(-t * decayRate)
          if decayEnv < envelopeFloor { break }
          let env = decayEnv * (1 - exp(-t / voice.attackTime))
          out[onset + k] += amp * env * sin(omega * Double(k))
        }
      }

      // §3.6: マレットノイズ（onset から 20 ms）
      if voice.malletNoiseLevel > 0 {
        var filter = Biquad.bandpass(center: malletNoiseCenter, q: malletNoiseQ, sampleRate: sampleRate)
        let noiseFrames = min(Int(malletNoiseDuration * sampleRate), totalFrames - onset)
        for k in 0..<noiseFrames {
          let t = Double(k) / sampleRate
          let white = Double.random(in: -1...1, using: &rng)
          let shaped = white * exp(-t / malletNoiseDecay)
          out[onset + k] += voice.malletNoiseLevel * gain * filter.process(shaped)
        }
      }
    }

    // §2.3: 末尾 60 ms は cosine フェードアウトでゼロに落とす
    let fadeFrames = min(Int(tailFadeDuration * sampleRate), totalFrames)
    for k in 0..<fadeFrames {
      let progress = Double(k + 1) / Double(fadeFrames)
      out[totalFrames - fadeFrames + k] *= 0.5 * (1 + cos(.pi * progress))
    }

    // §4: ピーク正規化。ソフトクリップは掛けない
    let peak = out.reduce(0) { max($0, abs($1)) }
    let scale = peak > 0 ? targetPeak / peak : 0
    return out.map { Float($0 * scale) }
  }

  /// §3.4: T60₁(f₀) = ringTime · (440 / f₀)^0.5、[0.5, 9.0] にクランプ
  static func fundamentalT60(ringTime: Double, f0: Double) -> Double {
    let t60 = ringTime * (referenceFrequency / f0).squareRoot()
    return min(max(t60, t60Range.lowerBound), t60Range.upperBound)
  }
}

/// §3.6: マレットノイズ整形用の 2次バンドパスフィルタ（RBJ Audio EQ Cookbook 準拠）。
struct Biquad {
  private let b0: Double
  private let b1: Double
  private let b2: Double
  private let a1: Double
  private let a2: Double
  private var z1 = 0.0
  private var z2 = 0.0

  private init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
    self.b0 = b0
    self.b1 = b1
    self.b2 = b2
    self.a1 = a1
    self.a2 = a2
  }

  static func bandpass(center: Double, q: Double, sampleRate: Double) -> Biquad {
    let omega = 2 * Double.pi * center / sampleRate
    let alpha = sin(omega) / (2 * q)
    let a0 = 1 + alpha
    return Biquad(
      b0: alpha / a0,
      b1: 0,
      b2: -alpha / a0,
      a1: -2 * cos(omega) / a0,
      a2: (1 - alpha) / a0
    )
  }

  mutating func process(_ input: Double) -> Double {
    // Transposed Direct Form II
    let output = b0 * input + z1
    z1 = b1 * input - a1 * output + z2
    z2 = b2 * input - a2 * output
    return output
  }
}
