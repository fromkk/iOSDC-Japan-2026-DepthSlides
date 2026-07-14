# DepthSlides

iOSDC 登壇資料。複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける、というテーマのスライド。

## ビルド

- `swift build` は使わないこと。**`xcodebuild`** を使ってビルド・検証すること。
- Xcode MCP が利用可能な場合はそちらを優先して使うこと。
- `xcodebuild` が `active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance` エラーで失敗する場合、`xcode-select` が Command Line Tools を指しており、フル Xcode を指していないことが原因。この設定変更はユーザー自身に行ってもらうこと（勝手に `xcode-select -s` を実行しない）。

## 構成

- `DepthSlides.xcodeproj`: アプリ本体（iOS/macOS）
- `DepthSlidesPackage`: スライド本体（`DepthSlidesSlides` ターゲット）と Markdown 変換ロジック（`MarkdownToSlide` ターゲット）の Swift Package
- スライド定義は `DepthSlidesPackage/Sources/DepthSlidesSlides/Slides/` 配下
