#!/usr/bin/env python3
"""Depth Pro の Core ML パッケージを取得する。

Depth Pro (apple/ml-depth-pro) は Apple の研究モデルだが、Apple 自身は
Core ML 形式 (.mlpackage) を公式配布していない。一方で Hugging Face の
`coreml-projects/DepthPro-coreml` に、Hugging Face 自身の
`huggingface/coreml-examples` リポジトリが Swift サンプルの動作対象として
参照している、信頼できる変換済み .mlpackage (DepthPro.mlpackage, 約1.9GB)
が存在する。

ゼロから coremltools でこのモデル（ViT + パッチフュージョンの複雑な構成）を
再変換するのはリスクが高く再現性の検証も難しいため、このスクリプトでは
その変換済みパッケージをダウンロードして利用する方針にした
（Apple 公式ではなくコミュニティ変換である点に注意。ライセンスは
apple-ascl [Apple Sample Code License]）。

参考: https://huggingface.co/coreml-projects/DepthPro-coreml

入出力仕様（モデルカード記載）:
  - 入力 `image`: 1536x1536 の ImageType ([1, 3, 1536, 1536])
  - 入力 `originalWidth`: リサイズ前の元画像の幅を表すスカラー ([1, 1, 1, 1] TensorType)
  - 出力 `depthMeters`: 1536x1536 の1チャンネル Tensor（メートル単位の深度）
"""

from __future__ import annotations

import argparse
from pathlib import Path

from _common import DEFAULT_MODELS_DIR, download_mlpackage

REPO_ID = "coreml-projects/DepthPro-coreml"
PACKAGE_NAME = "DepthPro.mlpackage"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_MODELS_DIR,
        help="mlpackage を配置するディレクトリ (デフォルト: %(default)s)",
    )
    args = parser.parse_args()

    print(f"Downloading {PACKAGE_NAME} from {REPO_ID} (~1.9GB) ...")
    dst = download_mlpackage(REPO_ID, PACKAGE_NAME, args.output)
    print(f"Saved to {dst}")

    try:
        import coremltools as ct

        spec = ct.models.MLModel(str(dst)).get_spec()
        print("\n--- Model I/O spec ---")
        print(spec.description)
    except Exception as exc:  # pragma: no cover - diagnostic only
        print(f"(coremltools spec dump skipped: {exc})")


if __name__ == "__main__":
    main()
