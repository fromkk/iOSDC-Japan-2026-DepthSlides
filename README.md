# DepthSlides

iOSDC Japan 2026 の登壇資料。「複数の深度推定モデルを比較して、iPhone で撮影した写真のボケをミラーレス級に近づける」というテーマのスライドです。

スライドそのものが [SlideKit](https://github.com/mtj0928/SlideKit) 製の SwiftUI アプリになっていて、発表中にその場で写真を撮り、複数の Core ML 深度推定モデルを走らせてボケを比較するデモをスライド内で実行します。

## 必要環境

- Xcode 26.4 以降（Swift 6.3 / 動作確認は Xcode 27）
- iOS 26 以降 / macOS 26 以降
- Python 3.10 以降（Core ML モデルの取得・変換スクリプト用）
- 依存パッケージ（SwiftPM が自動で解決）
  - [SlideKit](https://github.com/mtj0928/SlideKit)
  - [swift-markdown](https://github.com/swiftlang/swift-markdown)

## 構成

| パス | 内容 |
| --- | --- |
| `DepthSlides.xcodeproj` | Xcode プロジェクト。ターゲットは本体アプリ `DepthSlides`（iOS / macOS）と、宣伝スライドだけの単体アプリ `EventPR` の2つ |
| `DepthSlides/` | 本体アプリ。Presenter ウィンドウ・外部ディスプレイ出力・端末間同期・PDF / 原稿の書き出しを持つ |
| `EventPR/` | 登壇の最後に出すイベント宣伝スライドだけを表示する最小構成のアプリ |
| `DepthSlidesPackage/` | ローカル Swift Package。スライド本体（`DepthSlidesSlides`）、宣伝スライド（`EventPRSlides`）、Markdown → スライド変換（`MarkdownToSlide`）、効果音（`DinnerChimeKit`） |
| `DepthSlidesPackage/Sources/DepthSlidesSlides/Slides/` | スライド定義（1枚1ファイル） |
| `scripts/` | 深度推定モデルのダウンロード・変換スクリプトと、PDF / 原稿の書き出しスクリプト |
| `articles/` | 登壇内容を記事化するための原稿 |

## セットアップ

### 1. Core ML モデルを配置する（必須）

`.mlpackage` はサイズが大きいためリポジトリに含めていません。**ビルド前に最低でも1つ**、`scripts/` のスクリプトを実行して `DepthSlidesPackage/Sources/DepthSlidesSlides/Models/` に配置してください。

```sh
cd scripts
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..

# 例: Apple 配布の Depth Anything V2 Small をダウンロードするだけ（変換不要）
python scripts/download_depth_anything_v2_small.py
```

対応モデル（Depth Anything V2 / V3、Depth Pro、MiDaS Small）の一覧・変換手順・注意点は [`scripts/README.md`](scripts/README.md) を参照してください。Hugging Face から取得するモデルはそれぞれの利用規約に従い、必要に応じて `huggingface-cli login` もしくは環境変数 `HF_TOKEN` を設定してください。

### 2. 署名設定を自分のものに変える

`DEVELOPMENT_TEAM` と `PRODUCT_BUNDLE_IDENTIFIER`（`me.fromkk.*`）は作者のものが入っています。実機で動かす場合は Xcode の Signing & Capabilities で自分の Team / Bundle Identifier に差し替えてください。シミュレータおよび macOS で動かすだけなら変更は不要です。

## ビルド・実行

`swift build` は使えません（アプリターゲットを含むため）。**必ず `DepthSlides.xcodeproj` 経由でビルドしてください。**

```sh
# Xcode で開く
open DepthSlides.xcodeproj
```

コマンドラインからビルドする場合:

```sh
# macOS
xcodebuild build -project DepthSlides.xcodeproj -scheme DepthSlides -destination 'platform=macOS'

# iOS シミュレータ
xcodebuild build -project DepthSlides.xcodeproj -scheme DepthSlides \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 宣伝スライドだけの単体アプリ
xcodebuild build -project DepthSlides.xcodeproj -scheme EventPR -destination 'platform=macOS'
```

> `active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance` で失敗する場合は、`xcode-select` が Command Line Tools を指しています。`sudo xcode-select -s /Applications/Xcode.app` でフル Xcode に切り替えてください。

## 発表時の操作

macOS 版のキーボードショートカット:

| キー | 動作 |
| --- | --- |
| <kbd>→</kbd> / <kbd>Enter</kbd> | 次へ |
| <kbd>←</kbd> | 前へ |
| <kbd>⇧</kbd><kbd>⌘</kbd><kbd>P</kbd> | Presenter ウィンドウを開く |
| <kbd>⌘</kbd><kbd>E</kbd> | PDF を書き出す |

iOS 版は外部ディスプレイ接続時に、手元の画面と投影画面を別々に表示します。

同一ネットワーク上の Mac / iPhone は Bonjour（`_depthslides-sync._tcp`）でページ送りを同期し、iPhone で撮影した深度情報付きの写真を Mac に転送（`_depthslides-cap._tcp`）します。初回起動時にカメラ・ローカルネットワーク・写真ライブラリの許可を求めます。

## 書き出し

どちらも macOS 版アプリをビルドして起動引数経由で実行します。

```sh
# 全スライドを PDF に書き出す（既定: build/DepthSlides.pdf）
scripts/export_slides_pdf.sh [出力先.pdf]

# 全スライドの発表原稿を読み上げ用テキストに書き出す（既定: speakernote_tts.txt）
scripts/export_speaker_notes.sh [出力先.txt]
```

## ライセンス

本リポジトリはオープンソースではありません。詳細は [`LICENSE`](LICENSE) を参照してください。

- **できること**: ダウンロードして自分の端末でビルド・実行する、内容を読んで参考にする、私的に改変する
- **できないこと**: 再配布・再公開（改変物やビルドしたバイナリを含む）、作者以外による発表・上映での利用、商用利用

SlideKit・swift-markdown などのライブラリ、および `scripts/` で取得する Core ML モデルは、それぞれの配布元のライセンス・利用規約に従います。
