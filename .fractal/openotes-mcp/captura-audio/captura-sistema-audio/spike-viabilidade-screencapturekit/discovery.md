---
achievable: yes
node_type: leaf
confidence: high
created: 2026-03-16
---

## Reasoning

ScreenCaptureKit (macOS 13+) supports system audio capture natively via SCStreamConfiguration.capturesAudio without any virtual audio driver. Darwin 25.3.0 (macOS 26) ships with ScreenCaptureKit. The scope is a single self-contained Swift CLI program, and the pass/fail criterion is unambiguous — either audio bytes arrive in the output file or they don't.

## PRD seed

Build a standalone Swift CLI that uses ScreenCaptureKit with capturesAudio=true to capture full-system or per-app audio output to a WAV/PCM file for 10 seconds, running without any virtual audio driver, and produce a result document stating pass (with sample file) or fail (with exact error).
