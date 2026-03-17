---
predicate: "O sistema captura áudio do sistema operacional em tempo real usando a abordagem validada e entrega chunks de áudio utilizáveis para a camada de transcrição"
leaf_type: cycle
created: 2026-03-16
---

# PRD — Implementação da captura de áudio do sistema

## Objetivo

Refatorar o spike PoC (spike/capture-audio.swift) em um CLI Swift de produção que captura áudio do sistema via ScreenCaptureKit, converte para o formato contratado, e entrega chunks via protocolo IPC stdout.

## Referências

- Spike: spike/capture-audio.swift (ScreenCaptureKit capturesAudio=true, WAV Float32 48kHz stereo)
- Contrato: docs/audio-contract.md (WAV Int16 16kHz mono, 30s chunks, IPC stdout)

## Deliverables

### 1. Swift CLI — src/capture-system-audio.swift

Evolução do spike com:

- **Captura**: ScreenCaptureKit com capturesAudio=true (mesmo do spike)
- **Conversão de formato**: Float32 48kHz stereo → Int16 16kHz mono
  - Downsample: 48kHz → 16kHz (fator 3, decimação com filtro passa-baixa simples)
  - Downmix: stereo → mono (média L+R)
  - Requantize: Float32 → Int16 (×32767, clamp)
- **Chunking**: acumula 480.000 samples (30s × 16kHz), escreve WAV, emite CHUNK
- **Escrita atômica**: escreve em .tmp, rename para destino final
- **Diretório**: cria /tmp/openotes/chunks/ no startup
- **Protocolo stdout**: READY, CHUNK:<path>, ERROR:<desc>, DONE
- **SIGTERM**: captura sinal, finaliza chunk atual, escreve DONE, exit 0

### 2. Build script — src/build.sh

- swiftc com frameworks necessários (ScreenCaptureKit, AVFoundation, CoreMedia, Foundation)
- Target arm64-apple-macos13.0
- Output: src/capture-system-audio (binário)

## Acceptance criteria

1. `src/build.sh` compila sem erros nem warnings
2. Binário `src/capture-system-audio` inicia e emite READY no stdout
3. Com áudio tocando, emite CHUNK:<path> a cada ~30s
4. Arquivos WAV em /tmp/openotes/chunks/ são válidos: 16kHz, mono, 16-bit PCM
5. SIGTERM finaliza o chunk atual e emite DONE
6. Sem crashes ou memory leaks em captura de 5+ minutos

## Out of scope

- Captura de microfone (nó separado)
- Integração com Bun/TS (próxima etapa)
- Voice Activity Detection
- Compressão (mp3/opus)

## Constraints

- macOS 13+ (ScreenCaptureKit)
- Requer permissão Screen Recording
- Swift puro, sem dependências externas
