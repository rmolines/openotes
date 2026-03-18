#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$REPO_DIR/com.openotes.daemon.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.openotes.daemon.plist"

echo "Installing openotes daemon LaunchAgent..."

# Unload if already loaded (ignore errors)
launchctl unload "$PLIST_DST" 2>/dev/null || true

cp "$PLIST_SRC" "$PLIST_DST"
echo "Copied plist to $PLIST_DST"

launchctl load "$PLIST_DST"
echo "LaunchAgent loaded. Daemon will start automatically on login."
echo "To check status: launchctl list | grep openotes"
echo "To stop: launchctl unload $PLIST_DST"
