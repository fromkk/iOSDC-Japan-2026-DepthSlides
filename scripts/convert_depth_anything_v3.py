#!/usr/bin/env python3
"""Depth Anything 3 (da3-small) を Core ML に変換する。

NOTE: Depth Anything V3 は単純な単眼深度推定モデルではなく、ByteDance-Seed の
`Depth-Anything-3` という any-view（単数〜複数画像対応）の3D基盤モデル。
`da3-small` はその中で最も軽量なプリセットで、単一画像 (`image=[path]`) を
渡せばカメラ姿勢なしの単眼深度推定モードとして動作する
(https://github.com/ByteDance-Seed/Depth-Anything-3)。

このモデルの `DepthAnything3.inference()` は前処理・後処理・エクスポートまで
含む高レベル API で、内部の `self.model(...)` は
{depth, conf, exts, ixts, ...} 相当のテンソルを含む dict を返し、それを
`OutputProcessor` が `Prediction`（`.depth` など）に変換している。
`OutputProcessor` は numpy/Python 処理を含み `torch.jit.trace` できないため、
このスクリプトでは
  1. まず `model.inference()` を1回実行して "正解" の depth 配列を得る
  2. `self.model(...)` の生 dict 出力から、形状・値がその正解と一致する
     テンソルを探して depth に対応するキーを特定する
  3. そのキーだけを返す薄いラッパーを trace して coremltools で変換する
という手順を取っている。3の探索が失敗した場合はエラーで停止するので、
実際に実行して出力されるキー名・形状を確認しながら調整すること
（本スクリプトは "動く可能性が高い一次実装" であり、最終的な正しさは
実行結果で検証する必要がある）。

インストール:
  git clone https://github.com/ByteDance-Seed/Depth-Anything-3 /tmp/depth-anything-3
  依存関係の `xformers` は CUDA 前提でビルドされておりmacOSではソースビルドが
  失敗する（clang++が `-fopenmp` 未対応のため）。実体は DINOv2 実装の
  `try: from xformers.ops import SwiGLU / except ImportError:` という
  フォールバック付きオプション依存なので、`/tmp/depth-anything-3/pyproject.toml`
  の dependencies から `"xformers",` の行を削除してから
  `pip install -e /tmp/depth-anything-3` すること。

  さらに coremltools 8/9 系は numpy>=2 環境だと定数畳み込み時に
  `TypeError: only 0-dimensional arrays can be converted to Python scalars`
  で落ちる既知の非互換があるため、`pip install "numpy<2" "scipy<1.13"` して
  numpy を 1.x に固定すること（depth-anything-3 本家の pyproject.toml も
  元々 `numpy<2` を指定している。`requirements.txt` にも同じ制約を追加済み）。

  最後に、単一画像 (S=1) 推論時のみ発生するトレース時の shape 推論バグを
  避けるため、以下のファイルに1箇所手動パッチが必要
  （bicubic補間・cartesian_prod・meshgridの非対応は本スクリプト内で
  ランタイムにモンキーパッチ済みなので対応不要）:

  `src/depth_anything_3/model/dinov2/vision_transformer.py` の
  `_get_intermediate_layers_not_chunked` 内、カメラトークン割り当て部分
  ```python
  ref_token = self.camera_token[:, :1].expand(B, -1, -1)
  src_token = self.camera_token[:, 1:].expand(B, S - 1, -1)
  cam_token = torch.cat([ref_token, src_token], dim=1)
  x[:, :, 0] = cam_token
  ```
  を、S=1 で `expand(B, S - 1, -1)` が0要素次元になり
  coremltoolsのトレース時shape推論が誤って元のサイズのまま扱ってしまう問題を
  避けるため、以下に置き換える:
  ```python
  ref_token = self.camera_token[:, :1].expand(B, -1, -1)
  if S > 1:
      src_token = self.camera_token[:, 1:].expand(B, S - 1, -1)
      cam_token = torch.cat([ref_token, src_token], dim=1)
  else:
      cam_token = ref_token
  x[:, :, 0] = cam_token
  ```

  実際に上記すべての手順（xformers除去・numpy固定・カメラトークンパッチ）を
  適用し、本スクリプトで depth-anything/DA3-SMALL の変換が最後まで成功して
  DepthAnythingV3Small.mlpackage が生成されることを確認済み
  （入力 "image": [1,1,3,H,W] float16 MultiArray、
  出力 "depth": [1,1,H,W] float16 MultiArray）。
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

# torch / open3d / scikit-learn 等が各々 libomp.dylib を静的リンクしており、
# macOS ではプロセス内で二重初期化されクラッシュする
# (OMP: Error #15) ため、モデル変換専用スクリプトとして許容する。
os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import coremltools as ct
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from _common import DEFAULT_MODELS_DIR

# DINOv2 バックボーンの position embedding 補間 (interpolate_pos_encoding) は
# mode="bicubic" を使うが、coremltools の PyTorch フロントエンドは
# upsample_bicubic2d 未対応のため変換が失敗する。実行時に bilinear へ
# フォールバックさせるモンキーパッチ（変換専用スクリプト内でのみ有効）。
_original_interpolate = F.interpolate


def _interpolate_without_bicubic(input, *args, **kwargs):
  if kwargs.get("mode") == "bicubic":
    kwargs["mode"] = "bilinear"
  return _original_interpolate(input, *args, **kwargs)


F.interpolate = _interpolate_without_bicubic

# RoPE の2Dグリッド位置計算 (PositionGetter) は torch.cartesian_prod を使うが、
# これも coremltools の PyTorch フロントエンドが未対応のため、
# 数学的に等価な meshgrid + stack + reshape に置き換える
# （2引数のケースのみが実際に使われている）。
_original_cartesian_prod = torch.cartesian_prod


def _cartesian_prod_via_meshgrid(*tensors):
  if len(tensors) == 2:
    grids = torch.meshgrid(tensors[0], tensors[1], indexing="ij")
    return torch.stack(grids, dim=-1).reshape(-1, 2)
  return _original_cartesian_prod(*tensors)


torch.cartesian_prod = _cartesian_prod_via_meshgrid

# head_utils.create_uv_grid() の torch.meshgrid(x_coords, y_coords, indexing="xy")
# は入力が 1D の torch.linspace 出力のはずだが、coremltools のトレース時
# 型推論では non-1d と誤判定され `meshgrid received non-1d tensor.` で失敗する。
# 各入力を明示的に reshape(-1) してから渡すことで型推論を安定させる
# (既に1Dであれば no-op)。
_original_meshgrid = torch.meshgrid


def _meshgrid_force_1d(*tensors, **kwargs):
  flat = [t.reshape(-1) for t in tensors]
  return _original_meshgrid(*flat, **kwargs)


torch.meshgrid = _meshgrid_force_1d

MODEL_NAME = "depth-anything/DA3-SMALL"
PACKAGE_NAME = "DepthAnythingV3Small.mlpackage"
PROCESS_RES = 504


class DepthOnlyWrapper(nn.Module):
    """da3.model(...) の生 dict 出力から depth テンソルだけを返すラッパー。"""

    def __init__(self, da3_model: nn.Module, depth_key: str):
        super().__init__()
        self.model = da3_model
        self.depth_key = depth_key

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        raw = self.model(image, None, None, [], False, False, "saddle_balanced")
        return raw[self.depth_key]


def find_depth_key(raw_output: dict, expected_depth: np.ndarray) -> str:
    """raw dict の中から expected_depth (inference()実行結果) と一致するキーを探す。"""
    candidates = []
    for key, value in raw_output.items():
        if not torch.is_tensor(value):
            continue
        arr = value.detach().float().cpu().numpy()
        if arr.size == expected_depth.size:
            candidates.append((key, arr))

    for key, arr in candidates:
        if np.allclose(arr.reshape(-1), expected_depth.reshape(-1), rtol=1e-2, atol=1e-2):
            return key

    raise RuntimeError(
        "expected_depth と一致するキーが raw output 内に見つからなかった。"
        f" 候補 (形状のみ一致): {[(k, v.shape) for k, v in candidates]}\n"
        "手動で depth_anything_3 の model 実装 (src/depth_anything_3/model 以下) と"
        " OutputProcessor を確認し、正しいキー・後処理を特定すること。"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_MODELS_DIR,
        help="mlpackage を配置するディレクトリ (デフォルト: %(default)s)",
    )
    parser.add_argument(
        "--sample-image",
        type=Path,
        required=True,
        help="depth キー特定・トレース用のサンプル画像 (Portraitモード写真など)",
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    from depth_anything_3.api import DepthAnything3

    print(f"Loading {MODEL_NAME} ...")
    da3 = DepthAnything3.from_pretrained(MODEL_NAME)
    da3.eval()

    print("Running eager inference() for ground-truth depth ...")
    prediction = da3.inference(
        [str(args.sample_image)],
        process_res=PROCESS_RES,
        process_res_method="upper_bound_resize",
    )
    expected_depth = np.asarray(prediction.depth)
    print(f"Ground-truth depth shape: {expected_depth.shape}")

    imgs_cpu, _, _ = da3._preprocess_inputs(
        [str(args.sample_image)], None, None, PROCESS_RES, "upper_bound_resize"
    )
    imgs, _, _ = da3._prepare_model_inputs(imgs_cpu, None, None)

    with torch.no_grad():
        raw_output = da3.model(imgs, None, None, [], False, False, "saddle_balanced")

    depth_key = find_depth_key(raw_output, expected_depth)
    print(f"Found depth key: {depth_key!r}")

    wrapper = DepthOnlyWrapper(da3.model, depth_key).eval()
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (imgs,), strict=False)

    _, _, _, height, width = imgs.shape
    print(f"Converting to Core ML (input shape: 1x1x3x{height}x{width}) ...")
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="image", shape=imgs.shape)],
        outputs=[ct.TensorType(name="depth")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS17,
    )

    dst = args.output / PACKAGE_NAME
    mlmodel.save(str(dst))
    print(f"Saved to {dst}")

    spec = mlmodel.get_spec()
    print("\n--- Model I/O spec ---")
    print(spec.description)


if __name__ == "__main__":
    main()
