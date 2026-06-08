#!/usr/bin/env bash
# Rename the built ffmpeg binary to the Tauri sidecar filename for the
# given target triple, and stage it for upload.
#
# Usage: release-binary.sh <target> <src-binary> <staging-dir>
#
# Example:
#   release-binary.sh windows-x86_64 ffmpeg-src/ffmpeg.exe ./stage
#   release-binary.sh darwin-x86_64    ffmpeg-src/ffmpeg      ./stage
#   release-binary.sh darwin-aarch64   ffmpeg-src/ffmpeg      ./stage

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $0 <target> <src-binary> <staging-dir>" >&2
  exit 2
fi

TARGET="$1"
SRC="$2"
STAGE="$3"

if [ ! -f "$SRC" ]; then
  echo "FAIL: source binary not found: $SRC" >&2
  exit 1
fi

mkdir -p "$STAGE"

# Tauri sidecar filename convention. The `.exe` suffix is required on
# Windows; macOS and Linux sidecars have no suffix.
case "$TARGET" in
  windows-x86_64)
    OUT_NAME="ffmpeg-x86_64-pc-windows-msvc.exe" ;;
  darwin-x86_64)
    OUT_NAME="ffmpeg-x86_64-apple-darwin" ;;
  darwin-aarch64)
    OUT_NAME="ffmpeg-aarch64-apple-darwin" ;;
  *)
    echo "FAIL: unknown target '$TARGET'" >&2
    exit 1 ;;
esac

OUT="$STAGE/$OUT_NAME"
cp "$SRC" "$OUT"
chmod +x "$OUT"

# Print a single line of `key=value` for the workflow to consume.
echo "sidecar-name=$OUT_NAME"
echo "sidecar-path=$OUT"
echo "sidecar-size=$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")"
