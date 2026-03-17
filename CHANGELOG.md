# Changelog

## captura-microfone — local merge — 2026-03-16
**Type:** feat
**Node:** captura-microfone
**Commit:** `8bf6a32`
**What:** Swift CLI for microphone audio capture via AVAudioEngine. Same contract as system audio capture: Float32 hardware rate → Int16 16kHz mono, 30s WAV chunks to /tmp/openotes/mic-chunks/, IPC stdout protocol (READY/CHUNK/ERROR/DONE), SIGTERM graceful shutdown. Build script updated to compile both targets.
**Decisions:** see LEARNINGS.md#captura-microfone

## impl-captura-sistema — local merge — 2026-03-16
**Type:** feat
**Node:** impl-captura-sistema
**Commit:** `a5b0bd0`
**What:** Production Swift CLI for system audio capture via ScreenCaptureKit. Converts Float32 48kHz stereo → Int16 16kHz mono, writes 30s WAV chunks, IPC stdout protocol (READY/CHUNK/ERROR/DONE). Includes build and validation scripts.
