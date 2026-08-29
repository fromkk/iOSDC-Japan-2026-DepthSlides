#!/bin/zsh
# まとめ前の Before/After 比較スライド用の画像を、スライド本編と同じパイプライン
# （深度推定 → CIGaussianBlur を深度マスクで合成）で書き出す。
# 使い方: scripts/render_bokeh_before_after.sh <入力ディレクトリ> [出力先ディレクトリ]
#         (既定の出力先: build/bokeh_before_after)
# 出力: <元ファイル名>_before.png / <元ファイル名>_after.png
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <入力ディレクトリ> [出力先ディレクトリ]" >&2
  exit 1
fi

IN="$(cd "$1" && pwd)"
OUT="${2:-$ROOT/build/bokeh_before_after}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

echo "Building DepthSlides (macOS)..." >&2
xcodebuild build \
  -project "$ROOT/DepthSlides.xcodeproj" \
  -scheme DepthSlides \
  -destination 'platform=macOS' \
  -configuration Debug \
  -quiet

APP="$(xcodebuild -project "$ROOT/DepthSlides.xcodeproj" -scheme DepthSlides \
  -destination 'platform=macOS' -configuration Debug -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{d=$2} / FULL_PRODUCT_NAME = /{n=$2} END{print d"/"n}')"

if [[ ! -d "$APP" ]]; then
  echo "App not found: $APP" >&2
  exit 1
fi

# アプリは App Sandbox なので、入出力ともコンテナ内で行ってからコピーする
BUNDLE_ID="$(defaults read "$APP/Contents/Info.plist" CFBundleIdentifier)"
SANDBOX_ROOT="$HOME/Library/Containers/$BUNDLE_ID/Data/tmp/bokeh_before_after"
SANDBOX_IN="$SANDBOX_ROOT/in"
SANDBOX_OUT="$SANDBOX_ROOT/out"
rm -rf "$SANDBOX_ROOT"
mkdir -p "$SANDBOX_IN" "$SANDBOX_OUT"
# 画像だけをコピーする（拡張子は BokehBeforeAfterRenderer.imageURLs と揃える）
find "$IN" -maxdepth 1 -type f \
  \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' -o -iname '*.heif' -o -iname '*.png' \) \
  -exec cp {} "$SANDBOX_IN" \;

echo "Rendering via $APP ..." >&2
"$APP/Contents/MacOS/DepthSlides" --render-bokeh "$SANDBOX_IN" "$SANDBOX_OUT" 2>&1 \
  | grep --line-buffered -a -E "BokehRender|failed" >&2 || true

if [[ -n "$(ls -A "$SANDBOX_OUT" 2>/dev/null)" ]]; then
  cp "$SANDBOX_OUT"/* "$OUT/"
  rm -rf "$SANDBOX_ROOT"
  echo "Wrote images to $OUT" >&2
else
  echo "Render failed (no output in $SANDBOX_OUT)" >&2
  exit 1
fi
