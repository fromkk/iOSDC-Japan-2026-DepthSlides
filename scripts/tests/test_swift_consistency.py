"""各スクリプトが生成する .mlpackage 名と、Swift 側 (DepthModel.swift) が
`Bundle.module` から探す resourceName が一致していることを確認する。

ここがズレると、スクリプトを実行してモデルを配置したのにアプリ側が
`Models/` 内のファイルを見つけられず実行時に静かに失敗する
（DepthEstimationError.modelNotBundled）ため、ズレを検出できるようにしておく。
Swift コードのコンパイルはせず正規表現でのテキスト抽出のみ行う軽量なテスト。
"""

import re
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent
SWIFT_MODEL_FILE = (
  SCRIPTS_DIR.parent
  / "DepthSlidesPackage"
  / "Sources"
  / "DepthSlidesSlides"
  / "DepthEstimation"
  / "DepthModel.swift"
)

# (Pythonスクリプトのファイル名, そのスクリプトが出力する .mlpackage のベース名)
SCRIPT_PACKAGE_NAMES = {
  "download_depth_anything_v2_small.py": "DepthAnythingV2SmallF16",
  "convert_depth_pro.py": "DepthPro",
  "convert_midas_v3_small.py": "MiDaSSmall",
  "convert_depth_anything_v3.py": "DepthAnythingV3Small",
}


def _extract_package_name_constant(script_path: Path) -> str:
  content = script_path.read_text()
  match = re.search(r'PACKAGE_NAME\s*=\s*"([^"]+)\.mlpackage"', content)
  assert match, f"PACKAGE_NAME 定数が見つからない: {script_path}"
  return match.group(1)


def _extract_swift_resource_names() -> set[str]:
  content = SWIFT_MODEL_FILE.read_text()
  # `resourceName` の switch 内の `case .xxx: "ResourceName"` 形式を抽出
  body_match = re.search(r"var resourceName: String \{.*?\{(.*?)\}\s*\}", content, re.DOTALL)
  assert body_match, "resourceName の switch 文が見つからない"
  return set(re.findall(r'case\s+\.\w+:\s*"([^"]+)"', body_match.group(1)))


def test_each_script_package_name_matches_declared_constant():
  for script_name, expected in SCRIPT_PACKAGE_NAMES.items():
    actual = _extract_package_name_constant(SCRIPTS_DIR / script_name)
    assert actual == expected, f"{script_name}: PACKAGE_NAME={actual!r}, expected={expected!r}"


def test_all_script_package_names_are_referenced_by_swift_depth_model():
  swift_resource_names = _extract_swift_resource_names()
  for script_name, package_base_name in SCRIPT_PACKAGE_NAMES.items():
    assert package_base_name in swift_resource_names, (
      f"{script_name} が生成する {package_base_name}.mlpackage を "
      f"DepthModel.swift の resourceName が参照していない"
      f"（現在の resourceName 一覧: {sorted(swift_resource_names)}）"
    )


def test_swift_depth_model_does_not_reference_unknown_package_names():
  swift_resource_names = _extract_swift_resource_names()
  known_names = set(SCRIPT_PACKAGE_NAMES.values())
  unknown = swift_resource_names - known_names
  assert not unknown, (
    f"DepthModel.swift が参照しているが、対応するダウンロード/変換スクリプトが"
    f" scripts/ に存在しない resourceName: {sorted(unknown)}"
  )
