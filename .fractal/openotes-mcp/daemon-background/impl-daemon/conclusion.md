---
predicate: "Não existe daemon que rode o detect-meeting em background, envie notificação macOS ao detectar reunião, e inicie gravação quando o usuário confirma"
satisfied_date: 2026-03-17
satisfied_by: ship
---

## What was achieved
A background daemon (`src/openotes-daemon.ts`) now exists that continuously runs the `detect-meeting` binary, sends a macOS notification when a meeting is detected, and starts transcription recording only after the user explicitly confirms — satisfying the auto-detection and gated-recording requirement. The daemon is resilient to `detect-meeting` crashes (auto-respawn) and can be configured to start automatically at login via the included LaunchAgent plist and install script.

## Key decisions
- User confirmation via terminal stdin (not a dialog) keeps the daemon dependency-free and respects the "no auto-recording" constraint from the PRD.
- `import.meta.url` used for portable cwd in child process spawning — avoids hardcoding the repo path.
- detect-meeting respawn loop: 2s delay on unexpected exit prevents rapid crash loops while keeping recovery automatic.

## Deferred
- Menubar app / rich UI for notification interaction (explicitly out of scope in PRD).
- Calendar/EventKit integration for proactive pre-meeting notifications.
- Auto-recording mode without user confirmation.
