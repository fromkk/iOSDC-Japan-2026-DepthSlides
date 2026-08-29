# DepthSlides

iOSDC 登壇資料。複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける、というテーマのスライド。

## ビルド

- `swift build` は使わないこと。**`xcodebuild`** を使ってビルド・検証すること。
- Xcode MCP が利用可能な場合はそちらを優先して使うこと。
- `xcodebuild` が `active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance` エラーで失敗する場合、`xcode-select` が Command Line Tools を指しており、フル Xcode を指していないことが原因。この設定変更はユーザー自身に行ってもらうこと（勝手に `xcode-select -s` を実行しない）。

## 既知の落とし穴

- 動画を再生するスライド（`SaitamaSwiftPR` の `VideoPlayer`）のために、両アプリターゲットで `OTHER_LDFLAGS = -Wl,-needed_framework,AVKit` を指定している。AVKit を import しているのは `EventPRSlides` パッケージだけで、アプリのコードからは AVKit のシンボルを直接参照しないため、これがないとリンカが「未使用の dylib」として AVKit を落としてしまう。すると `_AVKit_SwiftUI` だけがリンクされた状態になり、**Release ビルドでのみ**動画スライドの表示時に `failed to demangle superclass of VideoPlayerView from mangled name 'So12AVPlayerViewC'` で abort する（Debug では再現しない）。

## 構成

- `DepthSlides.xcodeproj`: アプリ本体（iOS/macOS）と、宣伝スライドだけの単体アプリ `EventPR` の2ターゲット
- `DepthSlides/`: 本体アプリ。Presenter ウィンドウ・外部ディスプレイ・端末間同期・PDF 書き出しを持つ
- `EventPR/`: 宣伝スライドだけを表示する最小構成のアプリ。スライドをめくる以外の機能は持たない
- `DepthSlidesPackage`: スライド本体（`DepthSlidesSlides`）、イベント宣伝スライド（`EventPRSlides`）、Markdown 変換ロジック（`MarkdownToSlide`）の Swift Package
- スライド定義は `DepthSlidesPackage/Sources/DepthSlidesSlides/Slides/` 配下（宣伝パートのみ `Sources/EventPRSlides/Slides/`）
- 宣伝スライドは両アプリで共有する。`@Slide` マクロが生成するメンバーは public にできないため、スライド型は公開せず `EventPRDeck.slides`（`[any Slide]`）として受け渡し、`SlideIndexController(slides:)` に繋ぐ
