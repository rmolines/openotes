# Test Checklist
_Node: captura-audio/captura-microfone_
_Generated: 2026-03-16_

## How to use
1. Run each test below
2. Mark [x] for pass, [ ] for fail
3. Add notes for any failures
4. Run /fractal:review when done

---

## T1 — Microphone capture runtime behavior

title: Microphone capture — READY, CHUNK, DONE lifecycle
validates: Build script compila capture-mic-audio reproduzivelmente; binário existe e é executável
from: D2
steps:
1. Open Terminal and navigate to /Users/rmolines/git/openotes
2. Run: src/capture-mic-audio
3. If macOS prompts for microphone permission, grant it
4. Verify the first line printed is: READY
5. Wait approximately 30 seconds (speak or make ambient noise near the mic)
6. Verify a line appears in the format: CHUNK:/tmp/openotes/mic-chunks/chunk-<timestamp>-<seq>.wav
7. Press Ctrl+C to send SIGTERM
8. Verify the last line printed is: DONE
expected: First line is READY; after ~30s a CHUNK:<path> line appears; on Ctrl+C the last line is DONE
result: [ ]
notes:
