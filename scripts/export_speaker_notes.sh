#!/bin/zsh
# macOS 版アプリをビルドし、起動引数 --export-script で全スライドの原稿を
# 読み上げ用テキストに書き出す。
# 使い方: scripts/export_speaker_notes.sh [出力先.txt]   (既定: speakernote_tts.txt)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/speakernote_tts.txt}"
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
SANDBOX_OUT="$HOME/Library/Containers/$BUNDLE_ID/Data/tmp/DepthSlides_script.txt"
mkdir -p "$(dirname "$SANDBOX_OUT")"
rm -f "$SANDBOX_OUT"

echo "Exporting speaker notes via $APP ..." >&2
"$APP/Contents/MacOS/DepthSlides" --export-script "$SANDBOX_OUT" 2>&1 \
  | grep --line-buffered -a "ScriptExport" >&2 || true

if [[ -f "$SANDBOX_OUT" ]]; then
  mv "$SANDBOX_OUT" "$OUT"
  echo "$OUT"
else
  echo "Speaker note export failed (no output at $SANDBOX_OUT)" >&2
  exit 1
fi
