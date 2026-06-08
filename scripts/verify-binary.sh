#!/usr/bin/env bash
# Contract test for a freshly built ffmpeg sidecar.
#
# This is the hard evidence behind echo-flow's LGPL claim and the proof
# that the binary can run the exact transcode pipeline used by
# src-tauri/src/transcribe/audio.rs in echo-flow.
#
# Usage: verify-binary.sh <path-to-ffmpeg-binary>
#
# Exits 0 on success, non-zero on failure.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <ffmpeg-binary>" >&2
  exit 2
fi

BIN="$1"
if [ ! -x "$BIN" ]; then
  echo "FAIL: $BIN is not an executable file" >&2
  exit 1
fi

echo "==> Binary: $BIN"
echo "==> Size:   $(stat -c%s "$BIN" 2>/dev/null || stat -f%z "$BIN") bytes"
echo

# ---------------------------------------------------------------- license check
echo "==> Checking build configuration is LGPL..."

CONFIG=$("$BIN" -hide_banner -version 2>&1 | grep -i 'configuration' || true)
if [ -z "$CONFIG" ]; then
  echo "FAIL: could not read ffmpeg configuration line" >&2
  exit 1
fi
echo "$CONFIG" | head -c 200
echo "..."

if echo "$CONFIG" | grep -Eq -- "--enable-gpl|--enable-nonfree"; then
  echo >&2
  echo "FAIL: ffmpeg configuration has GPL or nonfree flags enabled:" >&2
  echo "$CONFIG" | grep -Eo -- "--enable-(gpl|nonfree)[^ ]*" >&2
  exit 1
fi

if echo "$CONFIG" | grep -q -- "--enable-version3"; then
  echo >&2
  echo "FAIL: --enable-version3 is present; this build is not LGPL 2.1+." >&2
  exit 1
fi

# Belt-and-suspenders: ensure no GPL-only decoder/demuxer/filter/encoder
# got enabled by accident. We maintain this list in lockstep with the
# whitelist in configure/common.sh — if you add a new GPL-only component
# there, add it here too.
for GPL_COMPONENT in \
  "libx264" "libx265" "libxavs" "libxavs2" "libxvid" \
  "libfdk-aac" "libfaac" "libaacplus" \
  "libaribcaption" "libarib24" "libdavs2" "libdvdread" "libdvdnav" \
  "libbluray" "libssh" "librtmp" "librtmpte" "librubberband" \
  "vid.stab" "libvidstab" "libdrm" "libxcb"; do
  if echo "$CONFIG" | grep -q -- "$GPL_COMPONENT"; then
    echo "FAIL: GPL-only component '$GPL_COMPONENT' is enabled in this build." >&2
    exit 1
  fi
done

echo "  license: LGPL ✓"
echo

# ---------------------------------------------------------------- transcode test
echo "==> Reproducing audio.rs transcode pipeline..."

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
SRC="$TMPDIR/in.mp3"
OUT="$TMPDIR/out.pcm"

# 1. Synthesize a 0.1s 440Hz sine wave and encode as mp3 with libmp3lame.
#    We use the bundled mp3lame because it's a common LGPL encoder; if
#    the build doesn't have it, fall back to the lavfi-adec flow.
if "$BIN" -hide_banner -loglevel error -h 2>&1 | grep -q "libmp3lame"; then
  "$BIN" -y -hide_banner -loglevel error \
    -f lavfi -i "sine=frequency=440:duration=0.1" \
    -c:a libmp3lame -b:a 64k "$SRC"
else
  # Fallback: use the wav muxer to produce a wav, then re-decode.
  WAV="$TMPDIR/in.wav"
  "$BIN" -y -hide_banner -loglevel error \
    -f lavfi -i "sine=frequency=440:duration=0.1" \
    -c:a pcm_s16le "$WAV"
  SRC="$WAV"
fi

# 2. The exact invocation from src-tauri/src/transcribe/audio.rs
#    (ffmpeg_args()). This is the contract: if this command produces
#    valid 16kHz mono s16le PCM, the sidecar is functionally correct.
"$BIN" -y -hide_banner -loglevel error \
  -nostdin \
  -threads 0 \
  -i "$SRC" \
  -f s16le \
  -ac 1 \
  -acodec pcm_s16le \
  -ar 16000 \
  "$OUT"

SIZE=$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")
# 0.1s * 16000Hz * 2 bytes/sample = 3200 bytes expected (allow ±200 for
# encoder/decoder boundary effects).
EXPECTED=3200
TOLERANCE=200
LOWER=$((EXPECTED - TOLERANCE))

if [ "$SIZE" -lt "$LOWER" ]; then
  echo "FAIL: transcode produced only $SIZE bytes (expected ~$EXPECTED)." >&2
  exit 1
fi

echo "  transcode: $SIZE bytes of 16kHz mono s16le PCM ✓"
echo

# ---------------------------------------------------------------- flag sanity
echo "==> Checking required decoders are present..."

for REQUIRED_DECODER in "pcm_s16le" "aac" "mp3" "opus" "vorbis" "flac"; do
  if ! "$BIN" -hide_banner -decoders 2>&1 | grep -q " $REQUIRED_DECODER "; then
    echo "FAIL: required decoder '$REQUIRED_DECODER' is missing." >&2
    exit 1
  fi
done

for REQUIRED_DEMUXER in "mov,mp4,m4a" "matroska" "mp3" "ogg" "wav"; do
  # demuxer list shows one per line; check by prefix
  case "$REQUIRED_DEMUXER" in
    "mov,mp4,m4a") PATTERN="mov," ;;
    *)             PATTERN="$REQUIRED_DEMUXER" ;;
  esac
  if ! "$BIN" -hide_banner -demuxers 2>&1 | grep -E " $PATTERN" >/dev/null; then
    echo "FAIL: required demuxer '$REQUIRED_DEMUXER' is missing." >&2
    exit 1
  fi
done

if ! "$BIN" -hide_banner -muxers 2>&1 | grep -q " s16le "; then
  echo "FAIL: required muxer 's16le' is missing." >&2
  exit 1
fi

if ! "$BIN" -hide_banner -protocols 2>&1 | grep -q "^  pipe$"; then
  echo "FAIL: required protocol 'pipe' is missing." >&2
  exit 1
fi

echo "  decoders/demuxers/muxers/protocols: all required components present ✓"
echo
echo "==> Sidecar contract test PASSED"
