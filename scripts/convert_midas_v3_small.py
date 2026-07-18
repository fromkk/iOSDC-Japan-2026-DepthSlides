#!/usr/bin/env python3
"""MiDaS small (EfficientNet-Lite3, 256x256) を ONNX から Core ML に変換する。

MiDaS v3.1 のモデルズーには v2.1 由来の軽量バックボーン
(`midas_v21_small_256`, EfficientNet-Lite3, 約21Mパラメータ, 256x256入力) が
「モバイル向け軽量モデル」として引き続き含まれている。isl-org が
MiDaS v2.1 の GitHub Release でこのモデルの ONNX 版
(`model-small.onnx`) を直接配布しているため、それをダウンロードし
coremltools で .mlpackage に変換する。

Depth Anything V2 Small / V3 (da3-small) / Depth Pro とは異なる、
古典的な CNN エンコーダベースの軽量モデルとして比較材料に加える。

参考:
  - https://github.com/isl-org/MiDaS (v3.1 モデルズー)
  - https://github.com/isl-org/MiDaS/releases/tag/v2_1 (model-small.onnx の配布元)
"""

from __future__ import annotations

import argparse
import tempfile
from pathlib import Path

import coremltools as ct
import onnx
import requests
import torch
from onnx2torch import convert as onnx_to_torch

from _common import DEFAULT_MODELS_DIR

ONNX_URL = "https://github.com/isl-org/MiDaS/releases/download/v2_1/model-small.onnx"
PACKAGE_NAME = "MiDaSSmall.mlpackage"
INPUT_SIZE = 256


def imagenet_scale_bias(mean: list[float], std: list[float]) -> tuple[float, list[float]]:
    """ImageNet 正規化 ((x/255 - mean) / std) を Core ML の ImageType が取る
    `scale`（全チャンネル共通のスカラー）・`bias`（チャンネル別）に変換する。

    `scale` はチャンネル共通の1値しか指定できないため、3チャンネルの std の
    平均を使って近似する（bias は per-channel 指定できるので mean は正確に処理する）。
    """
    avg_std = sum(std) / len(std)
    scale = (1.0 / 255.0) / avg_std
    bias = [-m / s for m, s in zip(mean, std)]
    return scale, bias


def download_onnx(dest: Path) -> Path:
    # 中間生成物の .onnx は SwiftPM の Models リソースディレクトリに混ぜたくない
    # ので、最終出力先 (--output) とは別の一時ディレクトリにキャッシュする。
    cache_dir = Path(tempfile.gettempdir()) / "depthslides-model-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    onnx_path = cache_dir / "midas_v21_small_256.onnx"
    if onnx_path.exists():
        print(f"Reusing cached {onnx_path}")
        return onnx_path

    print(f"Downloading {ONNX_URL} ...")
    response = requests.get(ONNX_URL, stream=True, timeout=120)
    response.raise_for_status()
    with open(onnx_path, "wb") as f:
        for chunk in response.iter_content(chunk_size=1 << 20):
            f.write(chunk)
    return onnx_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_MODELS_DIR,
        help="mlpackage を配置するディレクトリ (デフォルト: %(default)s)",
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    onnx_path = download_onnx(args.output)

    onnx_model = onnx.load(str(onnx_path))
    input_name = onnx_model.graph.input[0].name
    output_name = onnx_model.graph.output[0].name
    print(f"ONNX graph input: {input_name!r}, output: {output_name!r}")

    # coremltools 8+ は ct.convert() から直接 ONNX を読み込めなくなった
    # (source="onnx" が廃止された) ため、onnx2torch で一度 PyTorch モジュールに
    # 変換してから torch.jit.trace 経由で coremltools に渡す。
    torch_model = onnx_to_torch(onnx_model).eval()
    example_input = torch.zeros(1, 3, INPUT_SIZE, INPUT_SIZE)
    with torch.no_grad():
        traced_model = torch.jit.trace(torch_model, example_input)

    # model-small.onnx は正規化済み ImageNet 統計 (mean/std) を前提とした
    # [1, 3, 256, 256] float 入力を取る。
    mean = [0.485, 0.456, 0.406]
    std = [0.229, 0.224, 0.225]
    scale, bias = imagenet_scale_bias(mean, std)

    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.ImageType(
                name=input_name,
                shape=(1, 3, INPUT_SIZE, INPUT_SIZE),
                scale=scale,
                bias=bias,
                color_layout=ct.colorlayout.RGB,
            )
        ],
        outputs=[ct.TensorType(name=output_name)],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
    )

    dst = args.output / PACKAGE_NAME
    mlmodel.save(str(dst))
    print(f"Saved to {dst}")

    spec = mlmodel.get_spec()
    print("\n--- Model I/O spec ---")
    print(spec.description)


if __name__ == "__main__":
    main()
