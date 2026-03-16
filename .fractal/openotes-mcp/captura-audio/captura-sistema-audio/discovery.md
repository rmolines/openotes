---
achievable: yes
node_type: branch
confidence: high
created: 2026-03-16
---

## Reasoning

O predicado tem escopo claro, mas esconde uma premissa de viabilidade não validada: sem virtual audio driver instalado (BlackHole/Loopback ausentes), e a única alternativa nativa (ScreenCaptureKit) requer Swift/ObjC — ponte não trivial para stack Bun/TypeScript. A abordagem técnica precisa ser investigada antes de qualquer implementação.

## Proposed children

1. "É possível capturar áudio do sistema operacional no macOS sem instalar virtual audio driver de terceiros, usando apenas APIs nativas (ScreenCaptureKit, CoreAudio ou ffmpeg/AVFoundation)" — spike de viabilidade
2. "O sistema captura áudio do sistema operacional em tempo real usando a abordagem validada e entrega chunks de áudio utilizáveis" — implementação (só se #1 validar positivamente)
