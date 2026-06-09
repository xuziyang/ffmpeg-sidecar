#!/usr/bin/env bash
# Configure flags for the Windows x86_64 (MSVC ABI, built via mingw-w64
# cross-compile) ffmpeg sidecar.
#
# Result: a static LGPL-only ffmpeg.exe suitable for Tauri's sidecar.
#
# Run from the ffmpeg source tree:
#   bash ../configure/windows-x86_64.sh

set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

./configure \
  --prefix=/ffbuild/prefix \
  --pkg-config-flags=--static \
  --pkg-config=pkg-config \
  --cross-prefix=x86_64-w64-mingw32- \
  --ar=ar \
  --ranlib=ranlib \
  --strip=strip \
  --arch=x86_64 \
  --target-os=mingw32 \
  --enable-cross-compile \
  --enable-runtime-cpudetect \
  --disable-autodetect \
  --disable-debug \
  --disable-pthreads \
  --enable-w32threads \
  --disable-shared \
  --enable-static \
  --extra-ldflags="-static -static-libgcc" \
  --disable-bzlib \
  --disable-doc \
  --disable-iconv \
  --disable-lzma \
  --disable-sdl2 \
  --disable-zlib \
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
