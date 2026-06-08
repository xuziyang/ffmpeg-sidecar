# echo-flow-ffmpeg-sidecar

Builds the LGPL-only `ffmpeg` binary that
[echo-flow](https://github.com/xzygh/echo-flow) bundles as a Tauri sidecar
to decode and resample user audio for Whisper / Silero VAD / Wav2Vec2.

## Why this repo exists

`ffmpeg` is a vast project with many GPL-licensed components (x264, x265,
fdk-aac, arib24, ...). Public "LGPL" builds from third parties (BtbN,
gyan.dev, ...) often bundle those GPL components but simply omit the
`--enable-gpl` flag at configure time, producing binaries that are
**legally GPL** regardless of the marketing label.

This repo builds ffmpeg with `--disable-everything` and a small whitelist
of LGPL-licensed decoders, demuxers, and filters, and verifies the result
with a contract test that fails the build if any GPL component slipped in.

## Output

Each successful build produces a single ffmpeg executable named for Tauri's
sidecar convention:

| Target | File |
|--------|------|
| `windows-x86_64` | `ffmpeg-x86_64-pc-windows-msvc.exe` |
| `darwin-x86_64`  | `ffmpeg-x86_64-apple-darwin` |
| `darwin-aarch64` | `ffmpeg-aarch64-apple-darwin` |

These filenames are exactly what `src-tauri/tauri.conf.json`'s
`bundle.externalBin` expects in the consuming project.

## Build targets

| Target triple | Configure script | Runner |
|---------------|------------------|--------|
| `windows-x86_64` | `configure/windows-x86_64.sh` | `windows-latest` (mingw-w64 cross-compile) |
| `darwin-x86_64`  | `configure/darwin-x86_64.sh`  | `macos-13` (Intel) |
| `darwin-aarch64` | `configure/darwin-aarch64.sh` | `macos-latest` (Apple Silicon) |

Linux is intentionally not supported — see the [echo-flow README](https://github.com/xzygh/echo-flow).

## Triggers

| Trigger | Effect |
|---------|--------|
| `push` to `main` | Build all 3 targets, push a GitHub Release per target |
| `pull_request` | Build all 3 targets, run contract tests, do **not** push releases |
| `workflow_dispatch` | Manual / debug runs |
| `workflow_call` | Used by echo-flow's `tauri-build.yml` to fetch the artifact |

## Consuming from echo-flow

### Locally (developers)

```powershell
# Use gh CLI to download the latest release's asset for your host triple.
gh release download --repo xzygh/echo-flow-ffmpeg-sidecar --pattern 'ffmpeg-*-pc-windows-msvc.exe' --dir src-tauri/binaries
```

On macOS:

```bash
gh release download --repo xzygh/echo-flow-ffmpeg-sidecar \
  --pattern 'ffmpeg-*-apple-darwin' \
  --dir src-tauri/binaries
```

### In CI

`echo-flow/.github/workflows/tauri-build.yml` calls this workflow via
`workflow_call` and downloads the resulting artifact into
`src-tauri/binaries/` before running `npm run tauri build`.

## License

The ffmpeg binaries produced here are licensed under **LGPL 2.1+**.

The build configuration in `configure/common.sh` is the authoritative
whitelist. Adding a component to that file is a legal decision, not just a
technical one — please open an issue first if you want to extend it.

The contract test in `scripts/verify-binary.sh` enforces these invariants:

1. The `configuration` line printed by `ffmpeg -version` does **not**
   contain `--enable-gpl`, `--enable-nonfree`, or `--enable-version3`.
2. A hard-coded list of GPL-only component names (x264, x265, fdk-aac,
   arib24, libssh, libbluray, ...) does not appear in the configuration.
3. The binary can execute echo-flow's decode/resample pipeline and exposes
   the required decoders, demuxers, muxers, and protocols.

If you intentionally need a GPL component, the right answer is to fork
this repo — do not weaken the contract test.

## Repository layout

```
.
├── .github/workflows/build.yml     # CI: configure → make → verify → release
├── configure/
│   ├── common.sh                   # LGPL component whitelist
│   ├── windows-x86_64.sh
│   ├── darwin-x86_64.sh
│   └── darwin-aarch64.sh
└── scripts/
    ├── verify-binary.sh            # License + transcode contract test
    └── release-binary.sh           # Rename to Tauri sidecar filename
```
