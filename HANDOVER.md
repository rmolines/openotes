# Handover

## daemon-integration — 2026-03-18

**What was done:** The macOS app now reacts to the daemon in real time. `SessionStore` watches `data/transcriptions/` via `DispatchSource.makeFileSystemObjectSource` with `.write` eventMask, auto-calling `load()` when new session directories appear — no app restart needed. `openotes-daemon.ts` writes `data/.daemon-status.json` synchronously on recording state changes (startup → false, spawn → true + sessionId, stop → false). `AppDelegate` watches that file via its own DispatchSource and switches the NSStatusItem icon to `record.circle.fill` (red with palette tint) when `recording: true` is detected.

**Key decisions:**
- Synchronous `writeFileSync + renameSync` chosen over `Bun.write().then()` — eliminates the Promise-before-exit race on SIGTERM where `process.exit(0)` could fire before the atomic rename completed.
- `DispatchSource.makeFileSystemObjectSource` with `.write` eventMask on a directory fires when directory contents change (files/subdirs added or removed) on macOS — correct for detecting new `session-*/` directories.
- `dataDirURL` computed property in AppDelegate replicates `SessionStore.dataDir` logic exactly — single source of truth for path resolution is the OPENOTES_DATA_DIR env var pattern established by the data-layer-swift sibling node.
- AppDelegate creates `.daemon-status.json` with `recording: false` if it doesn't exist at launch — prevents a guard-return on first startup before the daemon runs.

**Pitfalls:**
- `DispatchSource` on a file (not directory) fires on `.write` when the file is replaced via rename — this is how atomic writes are detected correctly. Watching the directory for the file to change would NOT work; you must open the file itself with O_EVTONLY.

**Next steps:**
- Human-run AC6 validation: daemon + app, trigger recording, confirm auto-detection end-to-end.
- Parent predicate (macos-app) will be re-evaluated by the fractal tree.

**Key files:**
- `app/Sources/Openotes/SessionStore.swift` — DispatchSource watcher on transcriptions/
- `app/Sources/Openotes/AppDelegate.swift` — DispatchSource watcher on .daemon-status.json + icon logic
- `src/openotes-daemon.ts` — writeStatusFile() added

## data-layer-swift — 2026-03-18

**What was done:** The macOS app now has a working data layer. `SessionStore` discovers and loads real transcription sessions from disk at launch — scanning `data/transcriptions/session-*/`, decoding each segment JSON, and publishing them as `@Published var sessions: [Session]`. `ContentView` is wired with `@StateObject SessionStore` and shows session count. Path resolution works with `OPENOTES_DATA_DIR` env var or `../data` relative to CWD, so `swift run` from `app/` finds data without any extra configuration.

**Key decisions:**
- `FileManager.default.currentDirectoryPath` (CWD) used as path resolution base — not `Bundle.main.bundleURL`, which resolves to the `.build/` directory inside the SPM package. When running `swift run` from `app/`, CWD is the `app/` directory, so `../data` correctly resolves to the repo's `data/` directory.
- `Combine` imported in `SessionStore` for `ObservableObject` — this is the correct import even though the macro-like conformance looks like it could come from Foundation alone.
- `sourceAppName` left as `nil` — field is present in the model for future use (capture binary attribution) but no data source exists yet.

**Next steps:**
- Views layer (sibling node): sessions list grouped by day, transcription reader view, search — the data layer is now the foundation for the UI.

**Key files:**
- `app/Sources/Openotes/Models.swift` — TranscriptionSegment + Session structs
- `app/Sources/Openotes/SessionStore.swift` — ObservableObject with disk scanning and path resolution
- `app/Sources/Openotes/ContentView.swift` — wired with @StateObject

## scaffold-menubar-app — 2026-03-18

**What was done:** A macOS Menu Bar Popover app scaffold now exists at `app/`. Running `swift run` from that directory places a waveform icon in the system status bar; clicking the icon opens an NSPopover hosting a placeholder SwiftUI ContentView. The app has no Dock icon (activation policy set to `.accessory`). `swift build` exits 0. The existing CLI binaries in `src/` are untouched. This scaffold is the foundation for the real openotes UI (sessions list, search, live recording status).

**Key decisions:**
- SPM executable target (`Package.swift`) chosen over `.xcodeproj` — simpler, git-friendly, no Xcode required to build.
- `Info.plist` with `LSUIElement=true` is present in `app/Sources/Openotes/Info.plist` for documentation and future Xcode integration, but excluded from the SPM build (`exclude: ["Info.plist"]`). SPM rejects top-level Info.plist as a resource in executable targets. The no-Dock behavior is achieved identically via `NSApplication.shared.setActivationPolicy(.accessory)` in `main.swift`.
- `swiftLanguageVersions: [.v5]` set in Package.swift to avoid Swift 6 strict concurrency warnings in an AppKit/NSObject context.

**Pitfalls:**
- SPM cannot embed Info.plist into an executable via `.copy()` or `.process()` resources — it throws a build error. Use `setActivationPolicy(.accessory)` for the LSUIElement effect instead.

**Next steps:**
- Real content: sessions list (grouped by day), transcription viewer, search — parent predicate (macos-app) will be re-evaluated by the fractal tree.

**Key files:**
- `app/Package.swift` — SPM package definition
- `app/Sources/Openotes/AppDelegate.swift` — NSStatusItem + NSPopover lifecycle
- `app/Sources/Openotes/ContentView.swift` — placeholder SwiftUI view
- `app/Sources/Openotes/main.swift` — NSApplication entry point

## impl-daemon — 2026-03-17

**What was done:** The system now has a background daemon that closes the loop between meeting detection and recording. `bun run daemon` starts `src/openotes-daemon.ts`, which continuously runs `detect-meeting` (with auto-respawn on crash), sends a macOS notification when a meeting is detected, prompts the user in the terminal, and starts `transcribe-session` on confirmation. `MEETING_ENDED` triggers graceful SIGTERM to the recording process. A LaunchAgent plist and install script enable auto-start at login.

**Key decisions:**
- Notification via `osascript display notification` (no extra dependency). Terminal stdin prompt used for user confirmation since the daemon runs in a terminal and a full dialog/menubar app is out of scope.
- `import.meta.url` used for `cwd` in `spawnTranscribeSession` — avoids hardcoding the repo path and works from any install location.
- `detect-meeting` respawn loop: on unexpected exit, the daemon waits 2s and restarts. This handles binary crashes without bringing down the whole daemon.
- `transcribeProc` null-check before spawning: if a new MEETING_DETECTED fires while already recording, it is silently skipped (one active recording at a time).

**Pitfalls:**
- None new. See LEARNINGS.md for import.meta.url portable path pattern.

**Next steps:**
- parent predicate (daemon-background) will be re-evaluated by the fractal tree.
- Possible future: menubar app wrapping the daemon for richer UI (explicitly deferred in PRD).

**Key files:**
- `src/openotes-daemon.ts` — main daemon
- `com.openotes.daemon.plist` — LaunchAgent plist
- `scripts/install-daemon.sh` — install helper

## impl-deteccao — 2026-03-17

**What was done:** The system can now detect that a meeting is in progress. `src/detect-meeting` is a compiled Swift binary that polls every 3 seconds for active video-conference apps (Zoom, Teams, FaceTime, Webex via NSWorkspace) and Google Meet in any running browser (Chrome, Safari, Arc, Edge via osascript). It emits `MEETING_DETECTED:<source>` and `MEETING_ENDED` on stdout using the same protocol as the capture binaries. This unblocks the next node: integrating detection with recording orchestration.

**Key decisions:**
- NSWorkspace approach (zero new permissions) confirmed as primary detection method over Calendar/EventKit (requires permission) and audio detection (high false-positive risk without process filtering).
- osascript runs only when the target browser is already running (checked via NSWorkspace first) — avoids spurious Accessibility permission prompts on browsers not in use.
- State machine uses two simple states (idle/active) — no source tracking in the active state since the source is already emitted at transition time and the PRD's "simple state machine" constraint was respected.

**Pitfalls:**
- NSWorkspace requires AppKit, not just Foundation — without `-framework AppKit` in the swiftc invocation, NSWorkspace symbols are undefined even though the header is in the AppKit umbrella. The build fails with a linker error.

**Next steps:**
- Integrate `detect-meeting` with recording orchestration (next predicate: auto-start/stop recording on meeting detection).
- Calendar/EventKit integration deferred to V2 (proactive notification before meeting starts).

**Key files:**
- `src/detect-meeting.swift` — detection binary (NSWorkspace + osascript)
- `src/build.sh` — updated with third target

## mcp-server-exposicao — 2026-03-16

**What was done:** Meeting transcriptions are now accessible to AI agents via a local MCP server. Any Claude Code instance configured with the mcpServers snippet can call `list_sessions`, `get_session`, or `search_transcriptions` to retrieve and search through transcribed meeting content stored in `data/transcriptions/`.

**Key decisions:**
- `openserver` installed from `github:rmolines/openserver` (not npm — the npm package is an unrelated 2016 web server). The GitHub version is the Bun MCP framework the plan specified.
- All logging uses `process.stderr.write` exclusively — `console.log` writes to stdout and corrupts the MCP stdio framing, causing silent JSON-RPC parse failures on the client side.
- `TRANSCRIPTIONS_DIR` resolved via `process.cwd()` at module load time — server must be started from the repo root. This is a known openserver convention documented in its CLAUDE.md.
- `bun build --target bun` required — the default browser target fails on `process` imports inside openserver's dist bundle.

**Pitfalls:**
- `bun add openserver` installs the wrong package (v0.2.5, 2016). Use `bun add github:rmolines/openserver` to get the Bun MCP framework.
- Starting the server from a non-root CWD silently misdirects all data I/O — no error is thrown, tools just return empty results.

**Next steps:**
- Root predicate is the next evaluation point: "Existe um sistema open source que captura áudio de reuniões ao vivo, transcreve com IA de qualidade, e expõe as transcrições via MCP server para agentes terem contexto"
- All three sub-predicates (capture, transcription, MCP exposure) are now satisfied.

**Key files:**
- `src/mcp-server.ts` — MCP server with 3 custom tools
- `package.json` — `mcp` script + openserver dependency
- `README.md` — mcpServers configuration guide

## transcricao-ia — 2026-03-16

**What was done:** The TypeScript transcription layer is now live. Any WAV chunk produced by the capture binaries can be sent to Whisper API and its transcript persisted locally. The session orchestrator closes the loop: spawn capture → receive CHUNK signals → transcribe → log — with SIGTERM forwarding ensuring graceful shutdown without losing the in-flight chunk.

**Key decisions:**
- `import.meta.main` guard in `src/transcribe.ts` prevents the CLI entrypoint from triggering when the module is imported by the orchestrator — without this, `transcribe-session.ts` would crash on startup while trying to read stdin for a WAV path.
- FormData is rebuilt inside the `withRetry` lambda (not outside it), because Blob streams may be consumed after the first HTTP attempt. Each retry needs a fresh multipart form.
- Session ID derived from startup timestamp (`session-${Date.now()}`), not from chunk filenames, so all chunks from one session share a directory even if the capture process was restarted mid-session.
- `language=pt` passed to Whisper API to improve accuracy for Portuguese — Whisper can auto-detect but explicit language hints reduce misclassifications on short or noisy clips.

**Pitfalls:**
- `bun --check` does not exist in Bun 1.3. Use `bun build <file> --outdir /tmp` as the TypeScript validity check.
- The chunk file path passed to `transcribeChunk` must match the contract filename format (`chunk-{unix_ms}-{seq}.wav`) for session/seq parsing to work. Non-conforming paths fall back to `sessionId=Date.now(), seq=0`.

**Next steps:**
- MCP server node: expose `list_sessions`, `get_transcription`, `search_transcriptions` as MCP tools reading from `data/transcriptions/`.
- Both capture sources (system + mic) can be orchestrated simultaneously by running two session instances with different `--capture` flags.

**Key files:**
- `src/transcribe.ts` — Whisper API client + persistence
- `src/retry.ts` — generic exponential backoff utility
- `src/transcribe-session.ts` — session orchestrator
- `package.json` — `transcribe` and `session` scripts

## captura-microfone — 2026-03-16

**What was done:** Created `src/capture-mic-audio.swift`, a Swift CLI that captures default microphone input via AVAudioEngine, converts audio to the contracted format (Int16 16kHz mono WAV), and emits 30s chunks via the IPC stdout protocol. Updated `src/build.sh` to compile both system audio and microphone capture targets.

**Key decisions:**
- Used `inputNode.inputFormat(forBus: 0)` (hardware's native format) for the tap to avoid AVAudioEngine format mismatch errors — do not pass a different format to `installTap`.
- `floatChannelData` on AVAudioPCMBuffer returns non-interleaved (channel-per-pointer) buffers, not interleaved — the code manually interleaves before passing to AudioConverter.
- Decimation ratio is computed at runtime from hardware sample rate — handles both 44.1kHz (ratio≈2) and 48kHz (ratio=3) inputs.
- Output directory `/tmp/openotes/mic-chunks/` kept separate from system audio `/tmp/openotes/chunks/` so both capture processes can run concurrently.

**Pitfalls:**
- AVAudioEngine requires microphone TCC permission at runtime — no entitlement needed for CLI binaries, but the first run will prompt the user. Subsequent runs use the cached grant.
- On headless/CI environments, `engine.inputNode` will throw at start because no microphone is available. Guard for this in integration contexts.

**Next steps:**
- Bun orchestrator should be able to spawn both `capture-system-audio` and `capture-mic-audio` with separate chunk directories and merge transcription results.
- Transcription layer can now consume from two sources independently.

**Key files:**
- `src/capture-mic-audio.swift` — new CLI
- `src/build.sh` — updated with second target
- `docs/audio-contract.md` — chunk contract (unchanged, both CLIs comply)
