---
satisfied_by: patch
created: 2026-03-16
---

Contrato definido em docs/audio-contract.md: WAV 16-bit 16kHz mono, chunks de 30s, IPC via stdout (READY/CHUNK/ERROR/DONE), consumer Whisper API batch. Conversão de Float32 48kHz stereo → Int16 16kHz mono documentada.
