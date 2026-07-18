"""複数のダウンロード/変換スクリプトで共有するヘルパー。

このファイル自体は単独のエントリーポイントではなく、
`download_depth_anything_v2_small.py` / `convert_depth_pro.py` などから
import されるユーティリティ集。
"""

from __future__ import annotations

import shutil
from pathlib import Path

DEFAULT_MODELS_DIR = (
    Path(__file__).resolve().parent.parent
    / "DepthSlidesPackage"
    / "Sources"
    / "DepthSlidesSlides"
    / "Models"
)


def download_mlpackage(repo_id: str, package_name: str, output_dir: Path) -> Path:
    """Hugging Face の `repo_id` から `package_name`（.mlpackage ディレクトリ）
    だけを取得し、`output_dir/package_name` にコピーして配置する。

    既にダウンロード先に同名の .mlpackage が存在する場合は削除してから
    コピーし直す（中身が古いまま残らないようにするため）。
    """
    from huggingface_hub import snapshot_download

    output_dir.mkdir(parents=True, exist_ok=True)

    snapshot_dir = snapshot_download(
        repo_id=repo_id,
        allow_patterns=[f"{package_name}/*"],
    )

    src = Path(snapshot_dir) / package_name
    dst = output_dir / package_name
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    return dst
