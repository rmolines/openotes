---
node: captura-audio/captura-microfone
predicate: "O sistema captura áudio do microfone em tempo real e emite chunks no formato contratado"
created: 2026-03-16
status: approved
deliverables: 2
batches: 2
---

# Plan — Captura de áudio do microfone

## Project Context

Tree: openotes-mcp
Root: "Existe um sistema open source que captura áudio de reuniões ao vivo, transcreve com IA de qualidade, e expõe as transcrições via MCP server para agentes terem contexto"

Satisfied nodes:
- contrato-chunks: "O formato e contrato dos chunks de áudio está definido" → docs/audio-contract.md
- captura-sistema-audio: "O sistema captura áudio do SO em tempo real no macOS" → (satisfied via impl-captura-sistema)
- impl-captura-sistema: "O sistema captura áudio do SO usando abordagem validada" → src/capture-system-audio.swift, src/build.sh, src/validate.sh

Active: captura-audio/captura-microfone

## Functional Requirements

FR1: src/capture-mic-audio.swift compila sem erros
validates: build compila sem erros (acceptance criterion 1)
verified_by: D1 acceptance

FR2: Binário emite READY\n no stdout ao iniciar
validates: protocolo IPC inicializado corretamente (acceptance criterion 2)
verified_by: D2 acceptance (smoke test)

FR3: Binário emite CHUNK:<path> a cada ~30s de captura de microfone
validates: chunking e protocolo IPC durante captura (acceptance criterion 3)
verified_by: D2 human_test

FR4: WAV chunks são 16kHz, mono, 16-bit PCM conforme docs/audio-contract.md
validates: formato contratado (acceptance criterion 4)
verified_by: D1 acceptance (static code check + build verification)

FR5: SIGTERM causa shutdown gracioso com emissão de DONE\n
validates: graceful shutdown (acceptance criterion 5)
verified_by: D2 human_test

FR6: Build script compila o target capture-mic-audio reproduzivelmente
validates: build reproducível
verified_by: D2 acceptance

## Deliverables Summary

| ID | Title | Executor | Batch | Depends |
|----|-------|----------|-------|---------|
| D1 | Swift CLI — capture-mic-audio.swift | sonnet | 1 | none |
| D2 | Build script update + smoke test | haiku | 2 | D1 |

## Dependency Graph

```
D1 ──→ D2
```

## Batch Sequence

```
Batch 1: D1 (Swift CLI implementation)
Gate: D1 must compile before D2 proceeds
Batch 2: D2 (build script update — depends on D1)
```

---

## D1 — Swift CLI capture-mic-audio

**Executor:** sonnet
**Isolation:** none
**Depends on:** none
**Predicate:** Implementar CLI AVAudioEngine que captura microfone, converte Float32→Int16 16kHz mono, chunka 30s, emite IPC READY/CHUNK/DONE via stdout
**Files touched:**
- `src/capture-mic-audio.swift`

**Prompt for subagent:**

> You are implementing a Swift CLI that captures microphone audio on macOS and emits WAV chunks following a defined IPC contract.
>
> **Context:**
> - Repo: `openotes` at `/Users/rmolines/git/openotes/`
> - Stack: Swift (no external deps), macOS 13+, AVAudioEngine, AVFoundation, Foundation
> - The sibling file `src/capture-system-audio.swift` uses ScreenCaptureKit. You must follow the SAME patterns (WAVWriter class, ChunkManager, IPC stdout protocol, SIGTERM handler) but use AVAudioEngine for microphone input instead.
> - Chunk contract (from `docs/audio-contract.md`): WAV 16-bit PCM signed, 16kHz, mono, 30s per chunk (~960KB), written atomically to `/tmp/openotes/mic-chunks/`, named `chunk-{unix_ms}-{seq}.wav`
> - IPC stdout protocol: `READY\n`, `CHUNK:<path>\n`, `ERROR:<desc>\n`, `DONE\n`
> - build.sh uses: `-sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos13.0 -framework AVFoundation -framework Foundation -O`
>
> **Read these files before writing any code:**
> - `/Users/rmolines/git/openotes/src/capture-system-audio.swift` — copy the WAVWriter class and ChunkManager patterns exactly
> - `/Users/rmolines/git/openotes/docs/audio-contract.md` — the full IPC and chunk contract
> - `/Users/rmolines/git/openotes/src/build.sh` — understand the compile flags
>
> **What to do:**
> 1. Create `/Users/rmolines/git/openotes/src/capture-mic-audio.swift`
> 2. Import: Foundation, AVFoundation (AVAudioEngine lives here)
> 3. Copy WAVWriter class verbatim from sibling (it is self-contained and correct)
> 4. Implement a ChunkManager equivalent that accumulates 480,000 Int16 samples (30s at 16kHz) then flushes to a WAV file via WAVWriter, naming each file `chunk-{unix_ms_at_chunk_start}-{seq:03d}.wav` in `/tmp/openotes/mic-chunks/`
> 5. Audio capture setup:
>    - `let engine = AVAudioEngine()`
>    - `let inputNode = engine.inputNode`
>    - Install tap: `inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, time in ... }`
>    - In tap callback: convert buffer samples to Int16 16kHz mono and feed to ChunkManager
> 6. Conversion in tap callback (native hardware rate → 16kHz mono Int16):
>    - Get hardware sample rate from `inputNode.inputFormat(forBus: 0).sampleRate`
>    - Compute decimation ratio: `let ratio = Int(hardwareSampleRate / 16000.0)`  (typically 3 for 48kHz)
>    - Iterate through frames, step by ratio, downmix channels (average all channels), clamp Float32 to [-1, +1], multiply by 32767, convert to Int16
>    - If hardware rate is already 16kHz (ratio == 1), skip decimation
> 7. Startup sequence: create `/tmp/openotes/mic-chunks/` directory, call `try engine.start()`, print `READY` to stdout, flush
> 8. On each chunk completion: print `CHUNK:<full_path>` to stdout, flush
> 9. SIGTERM handler: set a flag → when tap fires after flag is set, flush partial chunk (even if < 480,000 samples, as long as samples > 0), print `DONE`, exit(0). Use `signal(SIGTERM, ...)` or a DispatchSource.
> 10. Keep the run loop alive: `RunLoop.main.run()` at the end of main
> 11. Compile to verify: `swiftc -O -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos13.0 -framework AVFoundation -framework Foundation src/capture-mic-audio.swift -o src/capture-mic-audio`
>
> **What NOT to do:**
> - Do NOT add device selection (CLI args for input device) — always use `engine.inputNode` (default)
> - Do NOT add echo cancellation, noise reduction, VAD, or post-processing
> - Do NOT capture system audio — that is `capture-system-audio.swift`
> - Do NOT write output to `/tmp/openotes/chunks/` — use `/tmp/openotes/mic-chunks/`
> - Do NOT add ScreenCaptureKit or CoreMedia imports — not needed for mic
> - Do NOT modify any existing files
>
> **Validation:**
> ```bash
> cd /Users/rmolines/git/openotes
> swiftc -O \
>   -sdk "$(xcrun --show-sdk-path)" \
>   -target arm64-apple-macos13.0 \
>   -framework AVFoundation \
>   -framework Foundation \
>   src/capture-mic-audio.swift \
>   -o src/capture-mic-audio 2>&1
> echo "Exit: $?"
> ```
> Expected: exit 0, zero errors (warnings acceptable).
>
> Static structure check:
> ```bash
> grep -c "READY\|CHUNK:\|DONE\|SIGTERM\|installTap\|AVAudioEngine\|WAVWriter\|Int16" src/capture-mic-audio.swift
> ```
> Expected: ≥ 8 matches.
>
> **Result format:**
> ```
> ## Result
> task_id: D1
> status: success | partial | failed
> summary: <1-2 sentences, what was done>
> errors: <list or empty>
> validation_result: <swiftc exit code + grep count>
> files_changed:
> - src/capture-mic-audio.swift
> ```

**Acceptance:** `swiftc -O -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos13.0 -framework AVFoundation -framework Foundation src/capture-mic-audio.swift -o src/capture-mic-audio` exits 0
**Human test:** No manual test needed at this stage — runtime behavior verified by D2's human test.

---

## D2 — Build script update + smoke test

**Executor:** haiku
**Isolation:** none
**Depends on:** D1
**Predicate:** Build script compila capture-mic-audio reproduzivelmente; binário existe e é executável
**Files touched:**
- `src/build.sh`

**Prompt for subagent:**

> You are updating the build script for the openotes project to add a build target for the microphone audio capture CLI.
>
> **Context:**
> - Repo: `openotes` at `/Users/rmolines/git/openotes/`
> - D1 already created `src/capture-mic-audio.swift`
> - Current `src/build.sh` builds only `capture-system-audio`. You must add a second build step for `capture-mic-audio`.
>
> **Read before editing:**
> - `/Users/rmolines/git/openotes/src/build.sh`
>
> **What to do:**
> 1. Read `src/build.sh`
> 2. Append a second build block after the existing one (do not remove or change the existing system audio build):
>    ```bash
>    SRC2="$SCRIPT_DIR/capture-mic-audio.swift"
>    OUT2="$SCRIPT_DIR/capture-mic-audio"
>    echo "Building $SRC2 -> $OUT2"
>    swiftc \
>      -sdk "$(xcrun --show-sdk-path)" \
>      -target arm64-apple-macos13.0 \
>      -framework AVFoundation \
>      -framework Foundation \
>      -O \
>      "$SRC2" \
>      -o "$OUT2"
>    chmod +x "$OUT2"
>    echo "Build succeeded: $OUT2"
>    ```
> 3. Run the updated build script: `bash src/build.sh`
> 4. Verify both binaries exist:
>    ```bash
>    ls -lh src/capture-system-audio src/capture-mic-audio
>    ```
>
> **What NOT to do:**
> - Do NOT modify the existing `capture-system-audio` build block
> - Do NOT create a separate build-mic.sh — update the existing build.sh
> - Do NOT modify any Swift files
>
> **Validation:**
> ```bash
> bash /Users/rmolines/git/openotes/src/build.sh && ls -lh /Users/rmolines/git/openotes/src/capture-mic-audio
> ```
> Expected: exit 0, both binaries listed.
>
> **Result format:**
> ```
> ## Result
> task_id: D2
> status: success | partial | failed
> summary: <1-2 sentences>
> errors: <list or empty>
> validation_result: <build output + ls output>
> files_changed:
> - src/build.sh
> ```

**Acceptance:** `bash src/build.sh` exits 0 and `src/capture-mic-audio` binary exists
**Human test:** Open Terminal in `/Users/rmolines/git/openotes`, run `src/capture-mic-audio`. macOS may prompt for microphone permission — grant it. The first line should be `READY`. After ~30s of speaking (or any ambient sound), a line `CHUNK:/tmp/openotes/mic-chunks/chunk-...wav` should appear. Press Ctrl+C — the last line should be `DONE`.

---

## Execution DAG

task: D1
title: Swift CLI — src/capture-mic-audio.swift
depends_on:
predicate: Implementar CLI AVAudioEngine que captura microfone, converte Float32→Int16 16kHz mono, chunka 30s, emite IPC READY/CHUNK/DONE via stdout
executor: sonnet
isolation: none
batch: 1
files:
- src/capture-mic-audio.swift
max_retries: 2
acceptance: swiftc -O -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos13.0 -framework AVFoundation -framework Foundation src/capture-mic-audio.swift -o src/capture-mic-audio exits 0
human_test: No manual test needed — runtime covered by D2

task: D2
title: Build script update + smoke test
depends_on: D1
predicate: Build script compila capture-mic-audio reproduzivelmente; binário existe e é executável
executor: haiku
isolation: none
batch: 2
files:
- src/build.sh
max_retries: 2
acceptance: bash src/build.sh exits 0 and src/capture-mic-audio binary exists
human_test: Run src/capture-mic-audio in terminal — prints READY, then CHUNK:<path> every ~30s, then DONE on Ctrl+C

## Infrastructure

Infrastructure: no changes needed.
