#!/usr/bin/env bash
# Configure flags for the macOS arm64 (Apple Silicon) ffmpeg sidecar.
#
# Must be run on macOS (uses the host Xcode/clang toolchain).
# Run from the ffmpeg source tree:
#   bash ../configure/darwin-aarch64.sh

set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

./configure \
  --prefix=/ffbuild/prefix \
  --pkg-config-flags=--static \
  --pkg-config=pkg-config \
  --arch=aarch64 \
  --target-os=darwin \
  --enable-runtime-cpudetect \
  --disable-debug \
  --disable-shared \
  --enable-static \
  --disable-doc \
  --disable-sdl2 \
  --disable-xlib \
  --disable-libxcb \
  --disable-libpulse \
  --disable-everything \
  --enable-decoder=$ENABLE_DECODERS \
  --enable-demuxer=$ENABLE_DEMUXERS \
  --enable-protocol=$ENABLE_PROTOCOLS \
  --enable-indev=$ENABLE_INDEVS \
  --enable-filter=$ENABLE_FILTERS \
  --enable-encoder=$ENABLE_ENCODERS \
  --enable-muxer=$ENABLE_MUXERS \
  "$@"
