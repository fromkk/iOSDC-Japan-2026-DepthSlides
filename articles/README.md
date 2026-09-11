# 登壇内容の記事化（note / Medium / dev.to）

iOSDC Japan 2026 のトーク内容を、note（日本語）と Medium / dev.to（英語）に投稿するための原稿と作業メモ。

| ファイル | 用途 |
| --- | --- |
| `note_ja.md` | note 向け日本語原稿。note のエディタに Markdown を貼り付ける前提 |
| `medium_en.md` | Medium 向け英語原稿。Medium の Import か、Markdown 対応ツールで流し込む |
| `devto_en.md` | dev.to 向け。`medium_en.md` の本文にフロントマターを付けたもの（見出しの H1 は `title` に移動済み） |

ルートにある `note.md` は初期の構成案で、現在のスライド（29枚）とは内容がずれている。参照せず、こちらの `note_ja.md` を正とする。

## 公開前チェックリスト

### 本文の TODO を埋める

各原稿の `<!-- TODO: ... -->` を検索して埋める。

- スライドの公開 URL（Speaker Deck など）
- サンプルコードのリポジトリ URL。リポジトリが非公開ならリンクを削除する
- Core AI の対応 SDK 表記。スライドの `19_ModelUsageNotes.swift` は「Xcode 27 / iOS 20 SDK」となっているが、iOS のバージョン番号が正しいか確認する
- dev.to の `cover_image` と `canonical_url`

### 画像を書き出す

原稿中の TODO に対応する画像。元素材は `DepthSlidesPackage/Sources/DepthSlidesSlides/` 配下。

| 記事内の位置 | 素材 |
| --- | --- |
| 冒頭のクイズ | `Media.xcassets/IMG_2569`（iPhone）と `SDIM4295_2`（SIGMA fp） |
| 凸レンズ | 08 スライドのシミュレーターをスクリーンショット |
| f値の実写 | `ApertureSamples/` |
| センサーサイズ | 11 スライド（`SensorSizeDiagramView`）をスクリーンショット |
| 埋め込み深度 | 17 スライドの元画像 / AVDepthData 比較（`DepthSamples/IMG_1606.heic`） |
| モデル比較 | 20 スライドのシミュレーターで同じ写真をモデル切り替えして撮る |
| フィルター比較 | 23 スライド（`BokehFilterResultGridView`）をスクリーンショット |
| 作例 Before / After | `Media.xcassets/result_0N_before` / `result_0N_after`（7組）。再生成するなら `scripts/render_bokeh_before_after.sh` |
| ToneCraft | `Media.xcassets/tone_craft_shot`、または `Resources/tone_craft_focus_blur.mp4` を GIF 化 |
| 背景削除 | 29 スライドのデモをスクリーンショット |

スライド全体の PDF は `scripts/export_slides_pdf.sh` で書き出せる。Speaker Deck に上げるのはこれ。

### 公開順と canonical

1. Medium に先に公開する（Medium は canonical 指定が Import 経由に限られるため、先に出すほうが楽）
2. dev.to は `canonical_url` に Medium の URL を入れて公開する（`published: true` に変更）
3. note は日本語で内容も別なので canonical は不要

逆に dev.to を正にしたい場合は、dev.to を先に公開して Medium 側は Import ツール（medium.com/p/import）で dev.to の URL を取り込むと canonical が付く。

### プラットフォームごとの差分

- **note**: 表（Markdown table）は貼り付けても表にならない。スペック比較表は画像にするか、箇条書きに崩す。コードブロックは対応している
- **Medium**: 表は非対応。同じくスペック比較表は画像にする。コードブロックはシンタックスハイライトなし
- **dev.to**: 表・コードブロックともにそのまま使える。タグは最大4つ（`ios, swift, coreml, machinelearning` を仮置き）

### 投稿後

- 各記事の末尾に相互リンク（日本語版 / English version）を追加する
- X（@fromkk）で告知するときは、冒頭のクイズ画像を添える
