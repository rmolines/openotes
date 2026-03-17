---
predicate: "O sistema captura áudio do sistema operacional em tempo real usando a abordagem validada e entrega chunks de áudio utilizáveis para a camada de transcrição"
satisfied_date: 2026-03-16
satisfied_by: ship
---

## What was achieved
O sistema agora possui um CLI Swift de produção que captura áudio do sistema operacional via ScreenCaptureKit, converte para WAV 16kHz mono 16-bit PCM, e entrega chunks de 30 segundos seguindo o protocolo IPC contratado (READY/CHUNK/ERROR/DONE via stdout).

## Key decisions
- Downsample 48kHz→16kHz com filtro LP 3-tap antes de decimação por fator 3
- Escrita atômica de chunks via .tmp rename
- SIGTERM handling via DispatchSource, flush de chunk parcial antes de exit

## Deferred
- Verificação de silêncio nos chunks (VAD)
- Compressão (opus/mp3) para reduzir tamanho
