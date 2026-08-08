import AVFoundation

extension AVAudioPCMBuffer {
  /// チャイムをレンダリングして PCM バッファ化する（仕様書 §4 / §5）。
  /// モノラルで生成し、各チャンネルへ同一波形をコピーする。
  public static func chime(
    _ sequence: ChimeSequence,
    voice: BarVoice = .default,
    sampleRate: Double = 48_000,
    channelCount: AVAudioChannelCount = 2,
    seed: UInt64 = 0x9E37_79B9_7F4A_7C15
  ) -> AVAudioPCMBuffer {
    let samples = ChimeRenderer.renderMono(
      sequence,
      voice: voice,
      sampleRate: sampleRate,
      seed: seed
    )
    guard
      let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(samples.count, 1)))
    else {
      preconditionFailure("Failed to allocate AVAudioPCMBuffer")
    }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    if let channels = buffer.floatChannelData {
      for channel in 0..<Int(channelCount) {
        for (index, sample) in samples.enumerated() {
          channels[channel][index] = sample
        }
      }
    }
    return buffer
  }
}
