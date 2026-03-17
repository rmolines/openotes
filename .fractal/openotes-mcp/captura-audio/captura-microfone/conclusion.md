---
predicate: "O sistema captura áudio do microfone em tempo real e emite chunks no formato contratado"
satisfied_date: 2026-03-16
satisfied_by: ship
---

## What was achieved

The microphone audio capture capability now exists: `src/capture-mic-audio` is a production Swift CLI that captures default microphone input via AVAudioEngine, converts it to the contracted format (WAV 16-bit PCM 16kHz mono, 30s chunks), and communicates with the Bun orchestrator via the same IPC protocol as the system audio capture. Both capture paths can now run concurrently with separate output directories.

## Key decisions

AVAudioEngine's non-interleaved buffer layout (`floatChannelData`) required explicit interleaving before conversion — different from ScreenCaptureKit's raw interleaved bytes. Hardware format is read at runtime so decimation ratio adapts to the actual device (44.1kHz or 48kHz). Output written to `/tmp/openotes/mic-chunks/` to avoid conflicts with system audio at `/tmp/openotes/chunks/`.

## Deferred

Device selection (non-default microphone input), echo cancellation, noise reduction, and VAD are explicitly out of scope. Runtime microphone permission handling in a sandboxed/app context would require an entitlement.
