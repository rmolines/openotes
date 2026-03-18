---
predicate: "O agente não consegue construir uma camada de dados Swift que descubra e leia corretamente as sessões de transcrição do disco — incluindo resolver o path do diretório data/ em runtime quando o binário roda fora da raiz do repo"
satisfied_date: 2026-03-18
satisfied_by: ship
---

## What was achieved
The macOS app now has a complete Swift data layer: `TranscriptionSegment` and `Session` Codable structs match the on-disk JSON format, and `SessionStore: ObservableObject` scans `data/transcriptions/` at launch, decodes all segment files, and publishes the sessions list. Path resolution works via `OPENOTES_DATA_DIR` env var or `../data` relative to CWD — `swift run` from `app/` finds real data without extra configuration. `ContentView` is wired with `@StateObject SessionStore` and shows live session counts.

## Key decisions
- CWD-based path resolution (`FileManager.default.currentDirectoryPath`) chosen over `Bundle.main.bundleURL` — SPM executables resolve bundle URL to `.build/`, not the repo root.
- `sourceAppName` present in `Session` but set to `nil` — reserved for future attribution from capture binaries.

## Deferred
- Full sessions list UI, transcription reader view, and search (handled by sibling views node).
- File watcher / live reload (explicitly out of scope in PRD).
