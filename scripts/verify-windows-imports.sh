#!/usr/bin/env bash
# Ensure the Windows sidecar does not depend on DLLs that are absent on a
# clean user machine. Run from MSYS2 after building ffmpeg.exe.
#
# Usage: verify-windows-imports.sh <path-to-ffmpeg.exe>

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <windows-ffmpeg-binary>" >&2
  exit 2
fi

BIN="$1"
if [ ! -f "$BIN" ]; then
  echo "FAIL: binary not found: $BIN" >&2
  exit 1
fi

if ! command -v objdump >/dev/null 2>&1; then
  echo "FAIL: objdump is required to inspect Windows DLL imports" >&2
  exit 1
fi

echo "==> Checking Windows DLL imports..."

mapfile -t IMPORTS < <(
  objdump -p "$BIN" |
    awk 'BEGIN { IGNORECASE = 1 } /DLL Name:/ { print tolower($3) }' |
    sort -u
)

if [ "${#IMPORTS[@]}" -eq 0 ]; then
  echo "FAIL: no DLL imports found; objdump may not have parsed the PE file" >&2
  exit 1
fi

echo "  imports: ${IMPORTS[*]}"

FAIL=0
for DLL in "${IMPORTS[@]}"; do
  case "$DLL" in
    api-ms-win-*.dll|ext-ms-*.dll|\
    advapi32.dll|bcrypt.dll|cfgmgr32.dll|combase.dll|crypt32.dll|\
    gdi32.dll|imm32.dll|iphlpapi.dll|kernel32.dll|msvcrt.dll|ntdll.dll|\
    ole32.dll|oleaut32.dll|rpcrt4.dll|secur32.dll|setupapi.dll|\
    shell32.dll|shlwapi.dll|ucrtbase.dll|user32.dll|uuid.dll|\
    version.dll|winmm.dll|ws2_32.dll)
      ;;
    *)
      echo "FAIL: non-system DLL import: $DLL" >&2
      FAIL=1
      ;;
  esac
done

if [ "$FAIL" -ne 0 ]; then
  echo "Windows sidecar must be a standalone executable plus Windows system DLLs only." >&2
  exit 1
fi

echo "  imports: Windows system DLLs only"
