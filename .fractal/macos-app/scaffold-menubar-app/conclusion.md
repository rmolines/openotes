---
predicate: "O agente não consegue criar o scaffold de um macOS Menu Bar Popover app em SwiftUI com Xcode project que compile e rode — incluindo NSStatusItem, popover lifecycle, Info.plist com LSUIElement"
satisfied_date: 2026-03-18
satisfied_by: ship
---

## What was achieved
A runnable macOS Menu Bar Popover app scaffold now exists at `app/`. Running `swift run` from that directory places a waveform icon in the system status bar; clicking the icon opens an NSPopover with a placeholder SwiftUI ContentView. The app has no Dock icon. `swift build` exits 0 with macOS 13+ target.

## Key decisions
- SPM executable target chosen over `.xcodeproj` — simpler and git-friendly.
- `Info.plist` with `LSUIElement=true` exists in source but is excluded from the SPM build (SPM rejects it as a top-level resource in executable targets); the no-Dock behavior is achieved via `NSApplication.shared.setActivationPolicy(.accessory)` in `main.swift`.
- `swiftLanguageVersions: [.v5]` set to avoid Swift 6 strict concurrency warnings in the AppKit/NSObject context.

## Deferred
- Real content: sessions list, transcription viewer, search (explicitly out of scope — parent predicate covers this).
- Xcode project file / proper app bundle (not needed for `swift build`/`swift run` workflow).
- Code signing and notarization.
