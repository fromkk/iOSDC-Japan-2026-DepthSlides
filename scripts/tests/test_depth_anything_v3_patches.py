"""convert_depth_anything_v3.py が定義するモンキーパッチ関数群のテスト。

これらは実際の Depth Anything 3 変換で
`NotImplementedError: PyTorch convert function for op '...' not implemented.`
（bicubic補間・cartesian_prod・非1D meshgrid）を回避するために追加したもの。
本テストは depth_anything_3 パッケージのインストールを必要とせず、
torch のみで各パッチ関数の入出力を検証する
（`main()` 内の実際のモデル変換ロジックはネットワーク・重いモデルロードが
必要なため対象外。docstring 記載の手動パッチ・モデル変換自体の成功は
実行時に scripts/README.md の手順で確認する）。

NOTE: `convert_depth_anything_v3` はインポート時に torch.cartesian_prod /
torch.meshgrid / F.interpolate をプロセス全体でモンキーパッチする
（変換スクリプト本体の設計上の挙動）。同一 pytest セッション内の他のテストが
これらの関数の元の挙動に依存している場合は影響を受ける可能性があるが、
本パッチはいずれも意味的に等価な代替（bicubic→bilinear、
cartesian_prod≡meshgrid+stack+reshape、meshgridの入力reshapeは1D入力には
no-op）なので実害はない想定。
"""

import torch
import torch.nn.functional as F

import convert_depth_anything_v3 as dav3


def test_interpolate_redirects_bicubic_to_bilinear():
  x = torch.arange(16, dtype=torch.float32).reshape(1, 1, 4, 4)
  patched = dav3._interpolate_without_bicubic(
    x, size=(8, 8), mode="bicubic", align_corners=False
  )
  bilinear = dav3._original_interpolate(x, size=(8, 8), mode="bilinear", align_corners=False)
  assert torch.allclose(patched, bilinear)


def test_interpolate_passes_through_non_bicubic_modes_unchanged():
  x = torch.arange(16, dtype=torch.float32).reshape(1, 1, 4, 4)
  patched = dav3._interpolate_without_bicubic(x, size=(8, 8), mode="nearest")
  original = dav3._original_interpolate(x, size=(8, 8), mode="nearest")
  assert torch.equal(patched, original)


def test_torch_functional_interpolate_is_monkeypatched_on_import():
  assert F.interpolate is dav3._interpolate_without_bicubic


def test_cartesian_prod_matches_itertools_product_order():
  # torch.cartesian_prod(y, x) は (y_i, x_j) を x が内側で回るループ順に返す。
  y = torch.arange(3)
  x = torch.arange(4)
  result = dav3._cartesian_prod_via_meshgrid(y, x)
  expected = torch.tensor([[yy.item(), xx.item()] for yy in y for xx in x])
  assert result.shape == (12, 2)
  assert torch.equal(result, expected)


def test_cartesian_prod_falls_back_to_original_for_non_pair_args():
  a, b, c = torch.arange(2), torch.arange(2), torch.arange(2)
  result = dav3._cartesian_prod_via_meshgrid(a, b, c)
  assert result.shape == (8, 3)


def test_torch_cartesian_prod_is_monkeypatched_on_import():
  assert torch.cartesian_prod is dav3._cartesian_prod_via_meshgrid


def test_meshgrid_force_1d_matches_original_for_already_1d_inputs():
  y = torch.arange(3)
  x = torch.arange(4)
  patched = dav3._meshgrid_force_1d(y, x, indexing="ij")
  original = dav3._original_meshgrid(y, x, indexing="ij")
  assert all(torch.equal(p, o) for p, o in zip(patched, original))


def test_meshgrid_force_1d_flattens_non_1d_inputs():
  y = torch.arange(3).reshape(3, 1)
  x = torch.arange(4)
  patched = dav3._meshgrid_force_1d(y, x, indexing="ij")
  assert patched[0].shape == (3, 4)
  assert patched[1].shape == (3, 4)


def test_torch_meshgrid_is_monkeypatched_on_import():
  assert torch.meshgrid is dav3._meshgrid_force_1d
