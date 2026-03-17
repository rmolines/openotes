---
predicate: "O sistema captura áudio do microfone em tempo real e emite chunks no formato contratado"
leaf_type: cycle
created: 2026-03-16
---

# PRD — Captura de áudio do microfone

## Objetivo

Criar CLI Swift que captura áudio do microfone via AVAudioEngine, seguindo o mesmo padrão e contrato de src/capture-system-audio.swift.

## Referências

- Sibling: src/capture-system-audio.swift (padrão a seguir)
- Contrato: docs/audio-contract.md (WAV Int16 16kHz mono, 30s chunks, IPC stdout)

## Deliverables

### 1. Swift CLI — src/capture-mic-audio.swift

Mesmo padrão do sibling com:
- **Captura**: AVAudioEngine com default input node (microfone)
- **Conversão**: Reusar mesmo AudioConverter (Float32 → Int16 16kHz mono)
- **Chunking**: Mesmo ChunkManager (480,000 samples = 30s)
- **IPC**: READY/CHUNK/ERROR/DONE via stdout
- **SIGTERM**: Graceful shutdown com flush de chunk parcial
- **Diretório**: /tmp/openotes/mic-chunks/ (separado do sistema)

### 2. Build script — atualizar src/build.sh

Adicionar target para capture-mic-audio (ou criar src/build-mic.sh separado).

## Acceptance criteria

1. Build compila sem erros
2. Binário emite READY no stdout ao iniciar
3. Falando no microfone, emite CHUNK:<path> a cada ~30s
4. WAV chunks são 16kHz, mono, 16-bit PCM
5. SIGTERM emite DONE

## Out of scope

- Captura de sistema (sibling separado)
- Seleção de dispositivo de áudio (usar default)
- Echo cancellation
- Noise reduction

## Constraints

- macOS 13+
- Swift puro, sem dependências externas
- Requer permissão de microfone (NSMicrophoneUsageDescription ou TCC)
