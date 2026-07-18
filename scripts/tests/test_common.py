"""_common.py（HFからの .mlpackage ダウンロード共通処理）のテスト。
ネットワークアクセスは行わず huggingface_hub.snapshot_download をモックする。
"""

from unittest import mock

import _common


def test_default_models_dir_points_at_swiftpm_resource_folder():
  assert _common.DEFAULT_MODELS_DIR.parts[-4:] == (
    "DepthSlidesPackage",
    "Sources",
    "DepthSlidesSlides",
    "Models",
  )


def test_download_mlpackage_copies_into_output_dir(tmp_path):
  fake_snapshot_dir = tmp_path / "hf_cache" / "some_repo"
  package_dir = fake_snapshot_dir / "Model.mlpackage"
  package_dir.mkdir(parents=True)
  (package_dir / "Manifest.json").write_text("{}")

  output_dir = tmp_path / "output"

  with mock.patch(
    "huggingface_hub.snapshot_download", return_value=str(fake_snapshot_dir)
  ) as mocked:
    dst = _common.download_mlpackage("some/repo", "Model.mlpackage", output_dir)

  mocked.assert_called_once_with(repo_id="some/repo", allow_patterns=["Model.mlpackage/*"])
  assert dst == output_dir / "Model.mlpackage"
  assert (dst / "Manifest.json").exists()


def test_download_mlpackage_replaces_stale_existing_copy(tmp_path):
  fake_snapshot_dir = tmp_path / "hf_cache" / "some_repo"
  package_dir = fake_snapshot_dir / "Model.mlpackage"
  package_dir.mkdir(parents=True)
  (package_dir / "new.txt").write_text("new")

  output_dir = tmp_path / "output"
  stale_dst = output_dir / "Model.mlpackage"
  stale_dst.mkdir(parents=True)
  (stale_dst / "old.txt").write_text("old")

  with mock.patch("huggingface_hub.snapshot_download", return_value=str(fake_snapshot_dir)):
    dst = _common.download_mlpackage("some/repo", "Model.mlpackage", output_dir)

  assert (dst / "new.txt").exists()
  assert not (dst / "old.txt").exists()
