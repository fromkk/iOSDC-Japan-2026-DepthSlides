import SwiftUI

private struct SlideAudioEnabledKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  /// メイン画面とPresenter画面で同じスライドViewが描画されるため、そのままだと
  /// 効果音・動画音声が二重に再生される。Presenter画面側でfalseを注入して、
  /// 音を伴うスライドはこの値を見て再生を抑制する。
  public var slideAudioEnabled: Bool {
    get { self[SlideAudioEnabledKey.self] }
    set { self[SlideAudioEnabledKey.self] = newValue }
  }
}
