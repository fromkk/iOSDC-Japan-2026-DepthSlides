#!/usr/bin/env python3
"""Depth Anything V2 Small (F16) を Apple 公式配布の Core ML パッケージからダウンロードする。

Apple が Hugging Face の `apple/coreml-depth-anything-v2-small` で
DepthAnythingV2SmallF16.mlpackage を配布しているため、変換は不要。
そのままダウンロードして DepthSlidesPackage の Models/ 配下に配置する。

参考: https://huggingface.co/apple/coreml-depth-anything-v2-small
"""

from __future__ import annotations

import argparse
from pathlib import Path

from _common import DEFAULT_MODELS_DIR, download_mlpackage

REPO_ID = "apple/coreml-depth-anything-v2-small"
PACKAGE_NAME = "DepthAnythingV2SmallF16.mlpackage"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_MODELS_DIR,
        help="mlpackage を配置するディレクトリ (デフォルト: %(default)s)",
    )
    args = parser.parse_args()

    print(f"Downloading {PACKAGE_NAME} from {REPO_ID} ...")
    dst = download_mlpackage(REPO_ID, PACKAGE_NAME, args.output)
    print(f"Saved to {dst}")


if __name__ == "__main__":
    main()
