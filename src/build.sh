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

SRC2="$SCRIPT_DIR/capture-mic-audio.swift"
OUT2="$SCRIPT_DIR/capture-mic-audio"
echo "Building $SRC2 -> $OUT2"
swiftc \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macos13.0 \
  -framework AVFoundation \
  -framework Foundation \
  -O \
  "$SRC2" \
  -o "$OUT2"
chmod +x "$OUT2"
echo "Build succeeded: $OUT2"

SRC3="$SCRIPT_DIR/detect-meeting.swift"
OUT3="$SCRIPT_DIR/detect-meeting"
echo "Building $SRC3 -> $OUT3"
swiftc \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macos13.0 \
  -framework Foundation \
  -framework AppKit \
  -O \
  "$SRC3" \
  -o "$OUT3"
chmod +x "$OUT3"
echo "Build succeeded: $OUT3"
