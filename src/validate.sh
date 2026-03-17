#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/capture-system-audio"
TIMEOUT=35
PASS=true
ERRORS=()

echo "=== openotes capture-system-audio validation ==="
echo "NOTE: Requires Screen Recording permission and audio playing during test."
echo ""

# Step 1: Build
echo "[1/5] Building binary..."
if ! bash "$SCRIPT_DIR/build.sh"; then
  echo "FAIL: build.sh exited non-zero"
  exit 1
fi
echo ""

# Step 2: Run binary for TIMEOUT seconds, capture stdout
echo "[2/5] Running binary for ${TIMEOUT}s..."
TMPOUT="$(mktemp /tmp/openotes-validate-stdout.XXXXXX)"
trap 'rm -f "$TMPOUT"' EXIT

"$BINARY" > "$TMPOUT" &
CHILD_PID=$!

sleep "$TIMEOUT"

if kill -0 "$CHILD_PID" 2>/dev/null; then
  echo "Sending SIGTERM to PID $CHILD_PID..."
  kill -TERM "$CHILD_PID"
  # Give it up to 5s to write DONE and exit
  for i in $(seq 1 10); do
    sleep 0.5
    kill -0 "$CHILD_PID" 2>/dev/null || break
  done
  # Force kill if still running
  kill -0 "$CHILD_PID" 2>/dev/null && kill -KILL "$CHILD_PID" 2>/dev/null || true
fi

wait "$CHILD_PID" 2>/dev/null || true
echo ""

STDOUT_CONTENT="$(cat "$TMPOUT")"

echo "--- stdout captured ---"
echo "$STDOUT_CONTENT"
echo "--- end stdout ---"
echo ""

# Step 3: Check READY
echo "[3/5] Checking protocol messages..."
if echo "$STDOUT_CONTENT" | grep -q "^READY$"; then
  echo "  [OK] READY emitted"
else
  echo "  [FAIL] READY not found in output"
  ERRORS+=("READY message missing")
  PASS=false
fi

# Check at least 1 CHUNK line
CHUNK_LINES="$(echo "$STDOUT_CONTENT" | grep "^CHUNK:" || true)"
if [ -n "$CHUNK_LINES" ]; then
  CHUNK_COUNT="$(echo "$CHUNK_LINES" | wc -l | tr -d ' ')"
  echo "  [OK] $CHUNK_COUNT CHUNK line(s) emitted"
else
  echo "  [FAIL] No CHUNK lines found — no audio was captured (is audio playing? is Screen Recording permitted?)"
  ERRORS+=("No CHUNK lines emitted")
  PASS=false
fi

# Check DONE
if echo "$STDOUT_CONTENT" | grep -q "^DONE$"; then
  echo "  [OK] DONE emitted"
else
  echo "  [FAIL] DONE not found — process may not have shut down gracefully"
  ERRORS+=("DONE message missing")
  PASS=false
fi
echo ""

# Step 4: Validate WAV files from CHUNK paths
echo "[4/5] Validating WAV files..."
if [ -n "$CHUNK_LINES" ]; then
  while IFS= read -r line; do
    WAV_PATH="${line#CHUNK:}"
    if [ -f "$WAV_PATH" ]; then
      FILE_OUTPUT="$(file "$WAV_PATH")"
      if echo "$FILE_OUTPUT" | grep -qi "RIFF\|WAV\|Audio"; then
        echo "  [OK] $WAV_PATH — $(file "$WAV_PATH" | cut -d: -f2- | xargs)"
      else
        echo "  [FAIL] $WAV_PATH exists but file command does not identify it as WAV: $FILE_OUTPUT"
        ERRORS+=("WAV file invalid: $WAV_PATH")
        PASS=false
      fi
    else
      echo "  [FAIL] $WAV_PATH does not exist"
      ERRORS+=("WAV file missing: $WAV_PATH")
      PASS=false
    fi
  done <<< "$CHUNK_LINES"
else
  echo "  [SKIP] No CHUNK paths to validate"
fi
echo ""

# Step 5: ffprobe validation (optional)
echo "[5/5] ffprobe audio format check (optional)..."
if command -v ffprobe &>/dev/null && [ -n "$CHUNK_LINES" ]; then
  FIRST_CHUNK="$(echo "$CHUNK_LINES" | head -1 | sed 's/^CHUNK://')"
  if [ -f "$FIRST_CHUNK" ]; then
    FFPROBE_OUT="$(ffprobe -v error -show_streams -select_streams a:0 \
      -of default=noprint_wrappers=1:nokey=0 "$FIRST_CHUNK" 2>&1 || true)"
    echo "  ffprobe output for $FIRST_CHUNK:"
    echo "$FFPROBE_OUT" | sed 's/^/    /'

    # Check sample rate
    SAMPLE_RATE="$(echo "$FFPROBE_OUT" | grep "^sample_rate=" | cut -d= -f2 | tr -d '[:space:]')"
    if [ "$SAMPLE_RATE" = "16000" ]; then
      echo "  [OK] sample_rate=16000"
    else
      echo "  [FAIL] sample_rate=$SAMPLE_RATE (expected 16000)"
      ERRORS+=("sample_rate mismatch: got $SAMPLE_RATE, expected 16000")
      PASS=false
    fi

    # Check channels
    CHANNELS="$(echo "$FFPROBE_OUT" | grep "^channels=" | cut -d= -f2 | tr -d '[:space:]')"
    if [ "$CHANNELS" = "1" ]; then
      echo "  [OK] channels=1 (mono)"
    else
      echo "  [FAIL] channels=$CHANNELS (expected 1)"
      ERRORS+=("channels mismatch: got $CHANNELS, expected 1")
      PASS=false
    fi

    # Check codec (pcm_s16le)
    CODEC="$(echo "$FFPROBE_OUT" | grep "^codec_name=" | cut -d= -f2 | tr -d '[:space:]')"
    if [ "$CODEC" = "pcm_s16le" ]; then
      echo "  [OK] codec=pcm_s16le"
    else
      echo "  [FAIL] codec=$CODEC (expected pcm_s16le)"
      ERRORS+=("codec mismatch: got $CODEC, expected pcm_s16le")
      PASS=false
    fi
  else
    echo "  [SKIP] First chunk file not found for ffprobe"
  fi
else
  echo "  [SKIP] ffprobe not available or no chunks to inspect"
fi
echo ""

# Final verdict
echo "================================================"
if [ "$PASS" = true ]; then
  echo "PASS — all checks passed"
  exit 0
else
  echo "FAIL — issues found:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi
