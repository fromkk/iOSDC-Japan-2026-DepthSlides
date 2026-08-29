// NOTE: AVKit は `OTHER_LDFLAGS = -Wl,-needed_framework,AVKit` で明示的に
// リンクしている。AVKit を import しているのは EventPRSlides パッケージ側だけで、
// アプリのコードからは AVKit のシンボルを直接参照しないため、そのままだと
// リンカが「未使用の dylib」として AVKit を落としてしまう。すると
// `_AVKit_SwiftUI` だけがリンクされた状態になり、Release ビルドで動画スライドを
// 表示した瞬間に `failed to demangle superclass of VideoPlayerView from mangled
// name 'So12AVPlayerViewC'` で abort する（Debug では再現しない）。
import EventPRSlides
import MarkdownToSlide
import SlideKit
import SwiftUI

/// 宣伝スライドだけを表示する単体アプリ。
/// 登壇資料本体（DepthSlides）と違い、Presenter ウィンドウ・外部ディスプレイ・
/// 端末間同期・PDF 書き出しは持たない最小構成にしている。
/// スライドの実体は `EventPRSlides` パッケージにあり、本体アプリと共有している。
@main
struct EventPRApp: App {
  @State private var configuration = EventPRSlideConfiguration()
  private let theme: MarkdownToSlide.SlideTheme = .default

  var body: some Scene {
    WindowGroup {
      PresentationView(slideSize: configuration.size) {
        ZStack {
          theme.backgroundColor
          SlideRouterView(slideIndexController: configuration.slideIndexController)
        }
      }
      .slideTheme(theme)
      .preferredColorScheme(.light)
      #if !os(macOS)
        // macOS はメニューのキーボードショートカットで進めるが、iOS には
        // メニューがないので画面の左右タップで進む・戻るを割り当てる。
        .overlay {
          HStack(spacing: 0) {
            tapArea { configuration.slideIndexController.back() }
            tapArea { configuration.slideIndexController.forward() }
          }
        }
      #endif
    }
    #if os(macOS)
      .windowStyle(.hiddenTitleBar)
      .commands {
        CommandGroup(after: .undoRedo) {
          Button("Forward") { configuration.slideIndexController.forward() }
            .keyboardShortcut(.rightArrow, modifiers: [])
          Button("Forward") { configuration.slideIndexController.forward() }
            .keyboardShortcut(.return, modifiers: [])
          Button("Back") { configuration.slideIndexController.back() }
            .keyboardShortcut(.leftArrow, modifiers: [])
        }
      }
    #endif
  }

  #if !os(macOS)
    private func tapArea(_ action: @escaping () -> Void) -> some View {
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }
  #endif
}
