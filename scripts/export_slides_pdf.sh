#!/bin/zsh
# macOS 版アプリをビルドし、起動引数 --export-pdf で全スライドを PDF に書き出す。
# 使い方: scripts/export_slides_pdf.sh [出力先.pdf]   (既定: build/DepthSlides.pdf)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build/DepthSlides.pdf}"
OUT="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd)/$(basename "$OUT")" || OUT="$ROOT/$OUT"

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

# アプリは App Sandbox なので、まずサンドボックス内に書き出してからコピーする
BUNDLE_ID="$(defaults read "$APP/Contents/Info.plist" CFBundleIdentifier)"
SANDBOX_OUT="$HOME/Library/Containers/$BUNDLE_ID/Data/tmp/DepthSlides_export.pdf"
mkdir -p "$(dirname "$SANDBOX_OUT")"
rm -f "$SANDBOX_OUT" "$OUT"

echo "Exporting PDF via $APP ..." >&2
# バイナリを直接起動すると stderr に進捗ログ（[PDFExport] ...）が流れる
"$APP/Contents/MacOS/DepthSlides" --export-pdf "$SANDBOX_OUT" 2>&1 \
  | grep --line-buffered -a "PDFExport" >&2 || true

if [[ -f "$SANDBOX_OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  mv "$SANDBOX_OUT" "$OUT"
  echo "$OUT"
else
  echo "PDF export failed (no output at $SANDBOX_OUT)" >&2
  exit 1
fi
