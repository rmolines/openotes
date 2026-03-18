# Changelog

## scaffold-menubar-app — PR #5 — 2026-03-18
**Type:** feat
**Node:** scaffold-menubar-app
**Commit:** `5b17949`
**What:** SPM-based macOS Menu Bar Popover app at `app/`. `AppDelegate` creates `NSStatusItem` (waveform icon); clicking toggles `NSPopover` hosting `SwiftUI ContentView` (placeholder). No Dock icon via `setActivationPolicy(.accessory)`. `swift build` exits 0. macOS 13+ target, Swift 5 language version. `Info.plist` with `LSUIElement=true` in source but excluded from SPM build.
**Decisions:** see LEARNINGS.md#scaffold-menubar-app

## impl-daemon — PR #4 — 2026-03-17
**Type:** feat
**Node:** impl-daemon
**Commit:** `6f85320`
**What:** Bun daemon `src/openotes-daemon.ts` that runs `detect-meeting` in a resilient respawn loop, sends macOS notifications via osascript on `MEETING_DETECTED:<source>`, prompts user via stdin, spawns `transcribe-session` on confirmation, and forwards SIGTERM on `MEETING_ENDED`. LaunchAgent plist `com.openotes.daemon.plist` (RunAtLoad) and `scripts/install-daemon.sh` for auto-start at login. `bun run daemon` script added to package.json.
**Decisions:** see LEARNINGS.md#impl-daemon

## impl-deteccao — PR #3 — 2026-03-17
**Type:** feat
**Node:** impl-deteccao
**Commit:** `589a1f5`
**What:** Swift binary `src/detect-meeting` that detects active meetings via NSWorkspace (Zoom, Teams, FaceTime, Webex) and osascript (Google Meet in Chrome/Safari/Arc/Edge). State machine emits `MEETING_DETECTED:<source>` / `MEETING_ENDED` on stdout. 3-second polling, graceful SIGTERM, zero new permissions. `build.sh` updated with third target (Foundation + AppKit).
**Decisions:** see LEARNINGS.md#impl-deteccao

## mcp-server-exposicao — PR #2 — 2026-03-16
**Type:** feat
**Node:** mcp-server-exposicao
**Commit:** `2fa3ddd`
**What:** MCP server exposing meeting transcriptions via openserver (stdio transport). Three custom tools: `list_sessions` (enumerate session dirs with metadata), `get_session` (ordered segments + full_text for a session), `search_transcriptions` (case-insensitive full-text search across all sessions). Added `"mcp"` npm script and Claude Code mcpServers config to README.
**Decisions:** see LEARNINGS.md#mcp-server-exposicao

## transcricao-ia — PR #1 — 2026-03-16
**Type:** feat
**Node:** transcricao-ia
**Commit:** `c2f08ee`
**What:** Bun/TypeScript transcription pipeline consuming WAV chunks from Swift capture processes. `src/transcribe.ts` POSTs chunks to Whisper API (model whisper-1, language=pt) and persists `{ chunk_path, timestamp, seq, text, duration_ms }` to `data/transcriptions/{session-id}/{seq}.json`. `src/retry.ts` provides generic exponential backoff (3 attempts, 1s/2s/4s). `src/transcribe-session.ts` orchestrates the full capture→transcription loop with graceful SIGTERM forwarding.
**Decisions:** see LEARNINGS.md#transcricao-ia

## captura-microfone — local merge — 2026-03-16
**Type:** feat
**Node:** captura-microfone
**Commit:** `8bf6a32`
**What:** Swift CLI for microphone audio capture via AVAudioEngine. Same contract as system audio capture: Float32 hardware rate → Int16 16kHz mono, 30s WAV chunks to /tmp/openotes/mic-chunks/, IPC stdout protocol (READY/CHUNK/ERROR/DONE), SIGTERM graceful shutdown. Build script updated to compile both targets.
**Decisions:** see LEARNINGS.md#captura-microfone

## impl-captura-sistema — local merge — 2026-03-16
**Type:** feat
**Node:** impl-captura-sistema
**Commit:** `a5b0bd0`
**What:** Production Swift CLI for system audio capture via ScreenCaptureKit. Converts Float32 48kHz stereo → Int16 16kHz mono, writes 30s WAV chunks, IPC stdout protocol (READY/CHUNK/ERROR/DONE). Includes build and validation scripts.
