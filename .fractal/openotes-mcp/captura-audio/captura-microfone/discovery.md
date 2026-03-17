---
response: leaf
confidence: high
leaf_type: cycle
created: 2026-03-16
---

## Reasoning

Padrão completamente estabelecido pelo sibling captura-sistema-audio. Contrato definido. WAVWriter/AudioConverter/ChunkManager reusáveis. Diferença: AVAudioEngine em vez de ScreenCaptureKit. Baixo risco.

## PRD seed

Criar src/capture-mic-audio.swift usando AVAudioEngine, reusando padrão do sibling, protocolo IPC stdout (READY/CHUNK/ERROR/DONE), SIGTERM handling.
