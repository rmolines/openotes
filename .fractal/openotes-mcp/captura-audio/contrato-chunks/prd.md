---
predicate: "O formato e contrato dos chunks de áudio está definido"
leaf_type: patch
created: 2026-03-16
---

# PRD — Contrato de chunks de áudio

## Decisão

Batch transcription via Whisper API.

## Contrato

| Campo | Valor |
|-------|-------|
| Codec | PCM 16-bit signed integer (linear PCM) |
| Sample rate | 16000 Hz |
| Channels | 1 (mono) |
| Chunk duration | 30 segundos |
| Container | WAV |
| Max file size | ~960 KB por chunk (well under Whisper's 25MB limit) |
| Delivery | Swift process escreve WAV files em diretório temporário |
| Naming | `chunk-{timestamp}-{seq}.wav` |

## IPC Swift → Bun

- Swift process escreve chunks WAV em `/tmp/openotes/chunks/`
- Emite uma linha no stdout quando um novo chunk está pronto: `CHUNK:/tmp/openotes/chunks/chunk-{ts}-{seq}.wav`
- Bun lê stdout line-by-line e processa cada chunk
- Start: Bun spawna o processo Swift como child process
- Stop: Bun envia SIGTERM, Swift finaliza o chunk atual e sai

## Acceptance criteria

1. Arquivo `docs/audio-contract.md` existe com o contrato documentado
2. O contrato é consumível sem transformação pela Whisper API
3. A interface IPC está documentada (stdout protocol)

## Out of scope

- Implementação do capture ou transcription — apenas o contrato
- Streaming transcription (Deepgram) — decisão futura se necessário
- Compressão (mp3/opus) — otimização futura
