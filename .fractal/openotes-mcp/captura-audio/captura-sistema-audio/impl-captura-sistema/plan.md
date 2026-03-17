---
predicate: "O sistema captura áudio do sistema operacional em tempo real usando a abordagem validada e entrega chunks de áudio utilizáveis para a camada de transcrição"
status: approved
created: 2026-03-16
deliverables: 2
batches: 1
---

# Plan — Implementação da captura de áudio do sistema

## Problem

Refatorar o spike PoC (spike/capture-audio.swift) em CLI Swift de produção que captura áudio do sistema via ScreenCaptureKit, converte Float32 48kHz stereo → Int16 16kHz mono, escreve chunks WAV de 30s, e comunica via protocolo stdout (READY/CHUNK/ERROR/DONE).

## Functional Requirements

FR1: Build compila sem erros
validates: CLI executável existe
verified_by: D1 acceptance

FR2: Binário emite READY no stdout ao iniciar
validates: protocolo IPC funciona
verified_by: D2 acceptance

FR3: Com áudio tocando, emite CHUNK:<path> a cada ~30s
validates: chunking funciona
verified_by: human_test

FR4: WAV chunks são 16kHz, mono, 16-bit PCM
validates: conversão de formato
verified_by: D2 acceptance (ffprobe)

FR5: SIGTERM finaliza chunk atual e emite DONE
validates: graceful shutdown
verified_by: D2 acceptance

## Project Context

Tree: openotes-mcp
Root: "Existe um sistema open source que captura áudio de reuniões ao vivo, transcreve com IA de qualidade, e expõe as transcrições via MCP server para agentes terem contexto"

Satisfied nodes:
- spike-viabilidade-screencapturekit: "ScreenCaptureKit capturesAudio=true funciona" → files: spike/capture-audio.swift, spike/build.sh
- contrato-chunks: "Contrato de chunks definido" → files: docs/audio-contract.md

Active: captura-audio/captura-sistema-audio/impl-captura-sistema

## Deliverables

### D1 — Production Swift CLI

**Executor:** sonnet
**Isolation:** none
**Depends on:** none
**Predicate:** Sistema captura áudio do SO e entrega chunks WAV Int16 16kHz mono de 30s via IPC stdout
**Files touched:**
- `src/capture-system-audio.swift`

**Prompt for subagent:**

> You are implementing: a production Swift CLI that captures macOS system audio via ScreenCaptureKit and delivers 30-second WAV chunks following a defined IPC protocol.
>
> **Context:**
> - Repo: `openotes` at `/Users/rmolines/git/openotes/`
> - This is an evolution of the spike at `spike/capture-audio.swift` — read it first for the working ScreenCaptureKit patterns
> - Audio contract defined in `docs/audio-contract.md` — read it for exact specs
> - Target: macOS 13+ (ScreenCaptureKit with capturesAudio)
>
> **What to do:**
>
> 1. Create `src/capture-system-audio.swift` based on the spike, with these changes:
>
> 2. **WAVWriter class** — rewrite for Int16 output:
>    - bitsPerSample = 16 (not 32)
>    - sampleRate = 16000, channelCount = 1
>    - WAV fmt chunk: size 16 (not 18), audioFormat 1 (PCM, not 3/IEEE float)
>    - write(samples:) takes [Int16] not [Float]
>    - Header is standard 44-byte RIFF/WAVE/fmt/data
>    - Accept output URL in init, write atomically: write to .tmp file, rename on close
>
> 3. **AudioConverter** — new class/struct for format conversion:
>    - Input: interleaved Float32 samples at 48kHz stereo (from ScreenCaptureKit CMSampleBuffer)
>    - Step 1 — Downmix: average pairs of samples (L+R)/2 → mono Float32 at 48kHz
>    - Step 2 — Downsample: simple decimation by factor 3 (take every 3rd sample). For better quality, apply a simple moving average low-pass filter (3-tap: [0.25, 0.5, 0.25]) before decimation
>    - Step 3 — Requantize: Float32 → Int16. Multiply by 32767, clamp to [-32768, 32767], cast to Int16
>    - Method signature: `func convert(interleavedFloat32: [Float], channelCount: Int) -> [Int16]`
>
> 4. **ChunkManager** — manages chunk accumulation and file writing:
>    - Target: 480,000 Int16 samples per chunk (30s × 16kHz)
>    - Accumulates converted samples in a buffer
>    - When buffer reaches target: write WAV to `/tmp/openotes/chunks/chunk-{unix_ms}-{seq}.wav` atomically
>    - Print `CHUNK:<path>` to stdout after successful write
>    - Sequence counter starts at 1, increments per chunk
>    - On flush (SIGTERM): write whatever is in buffer as a partial chunk (if >0 samples)
>
> 5. **AudioCaptureDelegate** — modify from spike:
>    - Extract Float32 samples from CMSampleBuffer (same as spike)
>    - Pass through AudioConverter
>    - Feed Int16 result to ChunkManager
>
> 6. **Main / run()** — modify from spike:
>    - Create `/tmp/openotes/chunks/` directory on startup (remove any existing files)
>    - Same ScreenCaptureKit setup as spike (capturesAudio=true, minimal video 2x2 1fps)
>    - Print `READY` to stdout after stream.startCapture() succeeds
>    - Run indefinitely (no 10-second sleep) — use RunLoop.main.run()
>    - Install SIGTERM handler using `signal(SIGTERM, ...)` or DispatchSource:
>      - Set a flag that the delegate checks
>      - Delegate flushes ChunkManager (partial chunk)
>      - Print `DONE` to stdout
>      - exit(0)
>    - On errors: print `ERROR:<description>` to stdout (non-fatal) or exit(1) (fatal)
>
> 7. Keep the `Data.append(littleEndianBytes:)` extension from the spike.
>
> **What NOT to do:**
> - Do NOT capture microphone audio — system audio only
> - Do NOT add any dependencies beyond Apple frameworks
> - Do NOT implement streaming/websocket — this is file-based chunking only
> - Do NOT add command-line argument parsing — hardcode all values
> - Do NOT touch the spike/ directory — leave it as-is for reference
>
> **Validation:** The file should be valid Swift that can be compiled with:
> ```
> swiftc -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos13.0 -framework ScreenCaptureKit -framework AVFoundation -framework CoreMedia -framework Foundation src/capture-system-audio.swift -o src/capture-system-audio
> ```
>
> **Result format:** when done, output a result block:
> ```
> ## Result
> task_id: D1
> status: success | partial | failed
> summary: <1-2 sentences>
> errors: <list or empty>
> validation_result: <build output>
> files_changed:
> - <paths>
> ```

**Acceptance:** `swiftc` compiles without errors or warnings
**Human test:** Run `src/capture-system-audio`, play some audio for 35+ seconds, verify READY appears immediately and CHUNK lines appear after ~30s. Ctrl-C to stop.

---

### D2 — Build + validation scripts

**Executor:** sonnet
**Isolation:** none
**Depends on:** D1
**Predicate:** Build e validação automatizados para o CLI de captura
**Files touched:**
- `src/build.sh`
- `src/validate.sh`
- `.gitignore`

**Prompt for subagent:**

> You are implementing: build and validation scripts for the capture-system-audio Swift CLI.
>
> **Context:**
> - Repo: `openotes` at `/Users/rmolines/git/openotes/`
> - The Swift CLI is at `src/capture-system-audio.swift`
> - Reference build script: `spike/build.sh` (similar but for the spike)
> - Audio contract: `docs/audio-contract.md`
>
> **What to do:**
>
> 1. Create `src/build.sh`:
>    ```bash
>    #!/usr/bin/env bash
>    set -euo pipefail
>    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
>    SRC="$SCRIPT_DIR/capture-system-audio.swift"
>    OUT="$SCRIPT_DIR/capture-system-audio"
>    echo "Building $SRC -> $OUT"
>    swiftc \
>      -sdk "$(xcrun --show-sdk-path)" \
>      -target arm64-apple-macos13.0 \
>      -framework ScreenCaptureKit \
>      -framework AVFoundation \
>      -framework CoreMedia \
>      -framework Foundation \
>      -O \
>      "$SRC" \
>      -o "$OUT"
>    chmod +x "$OUT"
>    echo "Build succeeded: $OUT"
>    ```
>
> 2. Create `src/validate.sh` — a script that:
>    - Builds the binary (calls build.sh)
>    - Runs it for 35 seconds (enough for 1 chunk)
>    - Captures stdout
>    - Sends SIGTERM after 35s
>    - Checks: READY was emitted, at least 1 CHUNK line appeared, DONE was emitted
>    - Checks: the WAV file from the CHUNK path exists and is valid (use `file` command to verify it's a WAV)
>    - If ffprobe is available: verify 16000 Hz, mono, s16le
>    - Prints PASS or FAIL with details
>    - Note: requires Screen Recording permission and audio playing during test
>
> 3. Add `src/capture-system-audio` to `.gitignore` (append, don't overwrite existing entries)
>
> 4. Run `bash src/build.sh` to verify it compiles
>
> **What NOT to do:**
> - Do NOT modify capture-system-audio.swift
> - Do NOT modify anything in spike/
>
> **Validation:** `bash src/build.sh` exits 0 and produces the binary
>
> **Result format:** when done, output a result block:
> ```
> ## Result
> task_id: D2
> status: success | partial | failed
> summary: <1-2 sentences>
> errors: <list or empty>
> validation_result: <build output>
> files_changed:
> - <paths>
> ```

**Acceptance:** `bash src/build.sh` exits 0
**Human test:** Run `bash src/validate.sh` with audio playing. Verify it prints PASS with details about the captured WAV chunk.

---

## Execution DAG

task: D1
title: Production Swift CLI — capture-system-audio.swift
depends_on:
predicate: Sistema captura áudio do SO e entrega chunks WAV Int16 16kHz mono de 30s
executor: sonnet
isolation: none
batch: 1
files:
- src/capture-system-audio.swift
max_retries: 2
acceptance: swiftc compiles without errors
human_test: Run binary, play audio 35s, verify READY and CHUNK lines on stdout

task: D2
title: Build + validation scripts
depends_on: D1
predicate: Build e validação automatizados para o CLI
executor: sonnet
isolation: none
batch: 1
files:
- src/build.sh
- src/validate.sh
- .gitignore
max_retries: 2
acceptance: bash src/build.sh exits 0
human_test: Run bash src/validate.sh with audio playing, verify PASS

## Infrastructure

Infrastructure: no changes needed.
