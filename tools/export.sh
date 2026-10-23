#!/usr/bin/env bash
# Builds distributable binaries with the Godot editor's headless exporter.
#
#   ./tools/export.sh apk      -> build/android/SINGULARITY.apk
#   ./tools/export.sh exe      -> build/windows/SINGULARITY.exe  (single file, PCK embedded)
#   ./tools/export.sh all      -> both
#
# Requirements (see README section 7):
#   * Godot 4.3+ on PATH as `godot`, or set GODOT=/path/to/godot
#   * Export templates for that exact version installed
#   * For Android: Android SDK + JDK configured in Godot's Editor Settings,
#     plus a debug keystore.
set -euo pipefail

GODOT="${GODOT:-godot}"
MODE="${1:-all}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: '$GODOT' not found. Install Godot 4.3+ or set GODOT=/path/to/godot" >&2
  exit 1
fi

echo "engine: $("$GODOT" --version 2>/dev/null || echo unknown)"
mkdir -p build/android build/windows

# Import once so .godot/ has resource metadata and .import files exist.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

build_apk() {
  echo "==> Android APK (debug signed)"
  "$GODOT" --headless --path "$ROOT" --export-debug "Android" "build/android/SINGULARITY.apk"
  echo "    done: build/android/SINGULARITY.apk"
}

build_exe() {
  echo "==> Windows executable"
  "$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "build/windows/SINGULARITY.exe"
  echo "    done: build/windows/SINGULARITY.exe"
}

case "$MODE" in
  apk) build_apk ;;
  exe|windows) build_exe ;;
  all) build_apk; build_exe ;;
  *) echo "usage: $0 [apk|exe|all]" >&2; exit 2 ;;
esac
