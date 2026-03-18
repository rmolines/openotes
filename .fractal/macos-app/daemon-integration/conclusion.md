---
predicate: "O app não consegue reagir em tempo real ao daemon — sem file watching, sem indicador de gravação ao vivo, sem refresh automático de novas sessões"
satisfied_date: 2026-03-18
satisfied_by: ship
---

## What was achieved
The macOS app now reacts to the daemon in real time: new recording sessions appear in the sessions list automatically without restarting the app, and the menu bar icon turns red when the daemon is actively recording. The daemon writes a status file (`data/.daemon-status.json`) on every state change, and both `SessionStore` and `AppDelegate` use `DispatchSource` file watchers to respond within milliseconds — no polling.

## Key decisions
- Synchronous `writeFileSync + renameSync` used in the daemon instead of `Bun.write().then()` to prevent a Promise-before-exit race on SIGTERM shutdown.
- `DispatchSource.makeFileSystemObjectSource` with `.write` eventMask on the transcriptions directory fires for new subdirectories; the same API used on the status file directly fires on atomic rename-based writes.
- `dataDirURL` in AppDelegate replicates `SessionStore.dataDir` path resolution (OPENOTES_DATA_DIR env var → CWD fallback) — no duplication of logic, same convention.

## Deferred
- Human end-to-end validation (AC6): start daemon + app, trigger recording, confirm auto-detection — requires physical hardware and a running meeting.
- Visual polish of recording indicator (explicitly out of scope in PRD).
- Daemon control from app (start/stop recording from the popover).
