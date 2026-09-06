import Foundation
import SlideKit

/// 全スライドの `script` を、本番と同じ順序（スライド送り・フェーズ送り）で
/// 読み上げ用テキストに書き出す。
///
/// `speakernote_tts.txt` を手で保守するとスライド側の変更に追従できないので、
/// 常にこの経路で再生成する。区切りの `[[slnc 1000]]` は macOS の `say` が
/// 解釈するポーズ指定で、スライド 1 枚ぶんの区切りに入れている。
@MainActor
struct SlideScriptExporter {
  /// スライドをまたぐ区切りに入れるポーズ（ミリ秒）。
  private static let slidePauseMilliseconds = 1000

  /// `slideIndexController` を先頭から最後まで送りながら原稿を集める。
  ///
  /// フェーズを持つスライドは `script` がフェーズごとに変わることがあるので、
  /// 1 ステップずつ進めて拾う。フェーズをまたいでも `script` が変わらない
  /// スライド（`var script: String = "..."` で固定しているもの）は、同じ文が
  /// 並ばないように直前と一致するものを畳む。
  static func scripts(of slideIndexController: SlideIndexController) -> [[String]] {
    slideIndexController.backToFirst()

    var perSlide: [[String]] = []
    var currentSlideIndex = slideIndexController.currentIndex
    var currentScripts: [String] = []

    func appendCurrent() {
      let script = slideIndexController.currentScript
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !script.isEmpty, script != currentScripts.last else { return }
      currentScripts.append(script)
    }

    appendCurrent()

    while slideIndexController.forward() {
      if slideIndexController.currentIndex != currentSlideIndex {
        perSlide.append(currentScripts)
        currentSlideIndex = slideIndexController.currentIndex
        currentScripts = []
      }
      appendCurrent()
    }
    perSlide.append(currentScripts)

    slideIndexController.backToFirst()
    return perSlide
  }

  /// 読み上げ用テキストに整形する。原稿を持たないスライドは区切りごと落とす。
  static func text(of slideIndexController: SlideIndexController) -> String {
    let separator = "[[slnc \(slidePauseMilliseconds)]]"
    let blocks =
      scripts(of: slideIndexController)
      .filter { !$0.isEmpty }
      .map { $0.joined(separator: "\n") }
    return blocks.joined(separator: "\n\(separator)\n") + "\n"
  }

  static func export(to url: URL, slideIndexController: SlideIndexController) throws {
    try text(of: slideIndexController).write(to: url, atomically: true, encoding: .utf8)
  }
}
