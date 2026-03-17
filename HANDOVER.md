# Handover

## captura-microfone — 2026-03-16

**What was done:** Created `src/capture-mic-audio.swift`, a Swift CLI that captures default microphone input via AVAudioEngine, converts audio to the contracted format (Int16 16kHz mono WAV), and emits 30s chunks via the IPC stdout protocol. Updated `src/build.sh` to compile both system audio and microphone capture targets.

**Key decisions:**
- Used `inputNode.inputFormat(forBus: 0)` (hardware's native format) for the tap to avoid AVAudioEngine format mismatch errors — do not pass a different format to `installTap`.
- `floatChannelData` on AVAudioPCMBuffer returns non-interleaved (channel-per-pointer) buffers, not interleaved — the code manually interleaves before passing to AudioConverter.
- Decimation ratio is computed at runtime from hardware sample rate — handles both 44.1kHz (ratio≈2) and 48kHz (ratio=3) inputs.
- Output directory `/tmp/openotes/mic-chunks/` kept separate from system audio `/tmp/openotes/chunks/` so both capture processes can run concurrently.

**Pitfalls:**
- AVAudioEngine requires microphone TCC permission at runtime — no entitlement needed for CLI binaries, but the first run will prompt the user. Subsequent runs use the cached grant.
- On headless/CI environments, `engine.inputNode` will throw at start because no microphone is available. Guard for this in integration contexts.

**Next steps:**
- Bun orchestrator should be able to spawn both `capture-system-audio` and `capture-mic-audio` with separate chunk directories and merge transcription results.
- Transcription layer can now consume from two sources independently.

**Key files:**
- `src/capture-mic-audio.swift` — new CLI
- `src/build.sh` — updated with second target
- `docs/audio-contract.md` — chunk contract (unchanged, both CLIs comply)
