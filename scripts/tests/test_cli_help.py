"""各スクリプトが最低限インポート・argparse セットアップに失敗しないことを
確認するスモークテスト。`--help` は依存モデルのダウンロード・重い変換ロジック
（`main()` 本体）に到達する前に `argparse` が `SystemExit(0)` するため、
ネットワークアクセスなしで実行できる
（`convert_depth_anything_v3.py` の depth_anything_3 インストールも不要）。
"""

import subprocess
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parent.parent

SCRIPT_NAMES = [
  "download_depth_anything_v2_small.py",
  "convert_depth_pro.py",
  "convert_midas_v3_small.py",
  "convert_depth_anything_v3.py",
]


@pytest.mark.parametrize("script_name", SCRIPT_NAMES)
def test_script_help_runs_without_error(script_name):
  result = subprocess.run(
    [sys.executable, str(SCRIPTS_DIR / script_name), "--help"],
    capture_output=True,
    text=True,
    timeout=60,
  )
  assert result.returncode == 0, result.stderr
  assert "--output" in result.stdout
