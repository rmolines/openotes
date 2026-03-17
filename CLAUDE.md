# CLAUDE.md — openotes

## Pitfalls

### AVAudioEngine mic capture fails silently on CI / headless environments
`src/capture-mic-audio` calls `engine.start()` which throws if no microphone input device is available (e.g., Docker, CI runners, SSH sessions without audio). Do NOT attempt to run this binary in automated test pipelines — it will exit with an error. Smoke tests for mic capture require physical hardware.

### AVAudioPCMBuffer is non-interleaved
`floatChannelData` on a tap buffer returns separate per-channel Float arrays, NOT interleaved samples. If you're adapting code from ScreenCaptureKit (which provides raw interleaved bytes), you must manually interleave before passing to conversion logic.

### build.sh builds both capture targets
`src/build.sh` compiles both `capture-system-audio` and `capture-mic-audio`. Both require Xcode Command Line Tools and macOS 13+. The system audio target additionally requires Screen Recording permission at runtime; the mic target requires Microphone permission.
