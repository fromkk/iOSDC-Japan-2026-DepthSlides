# モデルのダウンロード・変換スクリプト

深度推定モデルを Core ML (`.mlpackage`) として `DepthSlidesPackage/Sources/DepthSlidesSlides/Models/` に配置するためのスクリプト。
生成される `.mlpackage` はサイズが大きいためリポジトリには含めていない（`.gitignore` 参照）。**アプリをビルドする前に、最低でも1つのスクリプトを実行してモデルを配置しておく必要がある。**

## セットアップ

```sh
cd scripts
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 実行

すべてリポジトリのルートから実行し、出力先はデフォルトで `DepthSlidesPackage/Sources/DepthSlidesSlides/Models/` になる（`--output` で変更可能）。

```sh
# Apple 公式配布の .mlpackage をダウンロードするだけ（変換不要）
python scripts/download_depth_anything_v2_small.py

# 既存の信頼できる変換済み .mlpackage をダウンロードするだけ（変換不要、約1.9GB）
python scripts/convert_depth_pro.py

# Hugging Face の ONNX を取得して coremltools で変換
python scripts/convert_midas_v3_small.py

# Hugging Face から重みを取得して coremltools で変換
# (事前に ByteDance-Seed/Depth-Anything-3 のインストール・パッチが必要。
#  スクリプト冒頭の docstring を参照。--sample-image はトレース・検証用の
#  サンプル写真、Portraitモードなど適当な写真のパスを渡す)
python scripts/convert_depth_anything_v3.py --sample-image path/to/sample.jpg
```

各変換スクリプトは最後に `coremltools` で読み込んだモデルの入出力仕様（`get_spec()`）を標準出力にダンプする。Swift 側 (`DepthEstimation/DepthEstimator.swift`) の実装・調整時にこの出力を参照すること。

**4スクリプトとも実際に実行し、`.mlpackage` の生成とCore MLでの推論（NaNなし・妥当な値域）まで確認済み。**

## テスト

モデルのダウンロード・変換そのもの（ネットワーク・GB単位のモデル取得・重いGPU/CPU計算）は自動テストの対象にせず、実際に壊れやすかった箇所（正規化計算・coremltools変換を回避するモンキーパッチ・Python側とSwift側のファイル名整合性・CLIの起動）を軽量にテストする。

```sh
cd scripts
pip install -r requirements-dev.txt
pytest
```

| テストファイル | 内容 |
| --- | --- |
| `tests/test_common.py` | `_common.download_mlpackage` の配置・上書きロジック（`huggingface_hub.snapshot_download` はモック） |
| `tests/test_midas_normalization.py` | MiDaS変換のImageNet正規化 (`scale`/`bias`) 計算の数値検証 |
| `tests/test_depth_anything_v3_patches.py` | Depth Anything V3変換で使っているモンキーパッチ（bicubic→bilinear、cartesian_prod、非1D meshgrid回避）の入出力検証 |
| `tests/test_cli_help.py` | 各スクリプトが `--help` で正常終了する（import・argparseセットアップの壊れを検出） |
| `tests/test_swift_consistency.py` | 各スクリプトが出力する `.mlpackage` 名と `DepthModel.swift` の `resourceName` が一致しているか |

ネットワーク・実モデルを使った本当のダウンロード/変換の成功は、上記の自動テストではなく実際に「実行」セクションのコマンドを一度ずつ動かして確認すること。

## モデル一覧

| モデル | 取得方法 | 備考 |
| --- | --- | --- |
| Depth Anything V2 Small (F16) | Apple の Core ML Models ギャラリー (`apple/coreml-depth-anything-v2-small`) から直接ダウンロード | 変換不要。入力 "image" 518x392 ImageType、出力 "depth" 518x392 ImageType(grayscale) |
| Depth Anything V3 (da3-small) | Hugging Face (`depth-anything/DA3-SMALL`, ByteDance-Seed/Depth-Anything-3) から重み取得 → coremltools 変換 | 単純な軽量モデルではなく any-view 3D基盤モデルの最小プリセット。変換には手動パッチが必要（スクリプト内docstring参照）。入力 "image" [1,1,3,H,W] float16、出力 "depth" [1,1,H,W] float16 |
| Depth Pro | Hugging Face (`coreml-projects/DepthPro-coreml`) の変換済み .mlpackage を直接ダウンロード | 約1.9GB、macOS 限定運用を想定。ゼロから変換せず既存の信頼できる変換物を利用。入力 "image" 1536x1536 + "originalWidth" スカラー(float16)、出力 "depthMeters" [1,1,1536,1536] float16 |
| MiDaS Small | isl-org/MiDaS v2.1 リリースの ONNX (`model-small.onnx`) を取得 → onnx2torch 経由で coremltools 変換 | 軽量な代替候補として追加。coremltools 8/9 系は ONNX を直接読めなくなったため onnx2torch で PyTorch モジュール化してから変換している |

## 注意

- ビルド確認には `xcodebuild` または Xcode MCP を使うこと（`swift build` は使わない。詳細は `CLAUDE.md` 参照）。
- `apple/DepthPro` や Depth Anything 系の重みは Hugging Face の利用規約に従うこと。ダウンロードには Hugging Face のアカウント/トークンが必要な場合がある（`huggingface-cli login` もしくは環境変数 `HF_TOKEN`）。
- coremltools 8/9 系は numpy>=2 環境で `TypeError: only 0-dimensional arrays can be converted to Python scalars` を起こす既知の非互換があるため、`requirements.txt` で numpy を `<2` に固定している。
- `convert_depth_anything_v3.py` の実行には ByteDance-Seed/Depth-Anything-3 を別途 clone・`pip install -e` する必要があり、macOS 特有の問題（`xformers` のソースビルド失敗、DINOv2バックボーンの一部演算がcoremltools未対応）に対する回避策・パッチ手順をスクリプト冒頭の docstring にまとめてある。実行前に必ず読むこと。
