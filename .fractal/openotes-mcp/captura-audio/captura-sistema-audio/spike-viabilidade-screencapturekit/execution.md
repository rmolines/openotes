---
mode: patch
sub_predicate: "Build a standalone Swift CLI that uses ScreenCaptureKit with capturesAudio=true to capture full-system audio output to a WAV file for 10 seconds, without any virtual audio driver"
reasoning: "ScreenCaptureKit supports capturesAudio natively since macOS 13. Single Swift file + build script, pass/fail binary outcome."
created: 2026-03-16
---
