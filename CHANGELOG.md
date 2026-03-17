# Changelog

## impl-captura-sistema — local merge — 2026-03-16
**Type:** feat
**Node:** impl-captura-sistema
**Commit:** `a5b0bd0`
**What:** Production Swift CLI for system audio capture via ScreenCaptureKit. Converts Float32 48kHz stereo → Int16 16kHz mono, writes 30s WAV chunks, IPC stdout protocol (READY/CHUNK/ERROR/DONE). Includes build and validation scripts.
