---
response: leaf
confidence: high
leaf_type: cycle
created: 2026-03-16
---

## Reasoning

Ambas incertezas upstream resolvidas: spike valida ScreenCaptureKit, contrato define WAV 16-bit 16kHz mono 30s com IPC stdout. O que resta é refatorar spike em produção: conversão de formato, chunking, protocolo IPC, SIGTERM handling. Sprint, não patch — múltiplos concerns e decisões de estrutura.

## PRD seed

Refactor spike/capture-audio.swift into src/capture-system-audio.swift: production Swift CLI with format conversion (Float32 48kHz stereo → Int16 16kHz mono), 30s WAV chunking to /tmp/openotes/chunks/, stdout IPC (READY/CHUNK/ERROR/DONE), SIGTERM handling, updated build.sh.
