#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/capture-system-audio.swift"
OUT="$SCRIPT_DIR/capture-system-audio"
echo "Building $SRC -> $OUT"
swiftc \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macos13.0 \
  -framework ScreenCaptureKit \
  -framework AVFoundation \
  -framework CoreMedia \
  -framework Foundation \
  -O \
  "$SRC" \
  -o "$OUT"
chmod +x "$OUT"
echo "Build succeeded: $OUT"
