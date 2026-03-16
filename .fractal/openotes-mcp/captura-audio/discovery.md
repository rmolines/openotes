---
achievable: yes
node_type: branch
confidence: high
created: 2026-03-16
---

## Reasoning

O predicado conecta dois work streams independentes: captura de microfone (viável via ffmpeg/AVFoundation, risco baixo) e captura de áudio do sistema operacional (sem virtual audio driver instalado — BlackHole/Loopback ausentes — risco técnico não validado). "Chunks utilizáveis" pressupõe definição de formato/duração/sample rate antes da implementação.

## Environment findings

- ffmpeg disponível com suporte AVFoundation
- Sem BlackHole, Loopback ou SoundFlower instalado
- MSTeamsAudioDevice.driver e ParrotAudioPlugin.driver presentes (não servem como loopback genérico)
- macOS 26.3 — ScreenCaptureKit disponível mas requer permissões e não é trivial via Bun/TS

## Proposed children

1. "O formato e contrato dos chunks de áudio está definido (codec, sample rate, duração, estrutura de dados) de forma que a camada de transcrição consegue consumir sem transformação adicional"
2. "O sistema captura áudio do microfone em tempo real e emite chunks no formato contratado"
3. "O sistema captura áudio do sistema operacional (saída de apps de reunião) em tempo real e emite chunks no formato contratado"
