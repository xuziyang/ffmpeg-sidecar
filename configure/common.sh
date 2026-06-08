#!/usr/bin/env bash
# Shared component whitelist for building LGPL-only ffmpeg sidecars.
#
# All listed decoders/demuxers/filters/encoders are LGPL-licensed under
# ffmpeg's own licensing (LGPL 2.1+ when --enable-gpl is NOT passed). Adding
# a component here that is GPL-only will fail with a configure-time error,
# which is the desired safety net.
#
# The whitelist is intentionally minimal: echo-flow only needs to decode
# common audio containers and resample/remix down to 16kHz mono s16le PCM
# for Whisper / Silero VAD / Wav2Vec2.

# Audio decoders (LGPL).
ENABLE_DECODERS="aac,ac3,alac,flac,mp3,mp3float,opus,pcm_s16le,pcm_s16be,pcm_f32le,pcm_f32be,vorbis"

# Container demuxers.
ENABLE_DEMUXERS="aac,flac,matroska,mov,mp3,m4a,ogg,wav"

# IO protocols. `file` is the only one echo-flow uses, but `data` is
# useful for synthetic test inputs and is LGPL.
ENABLE_PROTOCOLS="file,data"

# Filters required for the transcode pipeline in
# src-tauri/src/transcribe/audio.rs (16kHz mono s16le PCM output).
#  - aresample: resample to target sample rate
#  - pan:       remix to mono
#  - aformat:   enforce sample format
#  - anull:     pass-through (sometimes injected by ffmpeg)
#  - format:    pixel/format negotiation
#  - abuffer, abuffersink: filter graph plumbing
ENABLE_FILTERS="aresample,pan,aformat,anull,format,abuffer,abuffersink"

# Only one encoder is needed: s16le PCM on stdout.
ENABLE_ENCODERS="pcm_s16le"

# Muxers: `null` is sufficient because we pipe to stdout.
ENABLE_MUXERS="null"
