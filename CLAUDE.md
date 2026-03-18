# CLAUDE.md — openotes

## Pitfalls

### `bun --check` does not exist in Bun 1.3
`bun --check src/file.ts` is not a valid command — Bun has no standalone type-check flag. Use `bun build <file> --outdir /tmp` to verify a TypeScript file compiles without errors. For strict type checking, install `typescript` as a dev dependency and run `bun tsc --noEmit`.

### AVAudioEngine mic capture fails silently on CI / headless environments
`src/capture-mic-audio` calls `engine.start()` which throws if no microphone input device is available (e.g., Docker, CI runners, SSH sessions without audio). Do NOT attempt to run this binary in automated test pipelines — it will exit with an error. Smoke tests for mic capture require physical hardware.

### AVAudioPCMBuffer is non-interleaved
`floatChannelData` on a tap buffer returns separate per-channel Float arrays, NOT interleaved samples. If you're adapting code from ScreenCaptureKit (which provides raw interleaved bytes), you must manually interleave before passing to conversion logic.

### `bun add openserver` installs the wrong package
The npm registry has a 2016 package named `openserver` (v0.2.5, a simple web server). `bun add openserver` silently installs it. For the Bun MCP framework used by this project, use `bun add github:rmolines/openserver`. Verify by checking exports: the correct package exports `createServer` and `defineSchema`; the wrong one exports `startServer`.

### `console.log` in `src/mcp-server.ts` corrupts the MCP protocol
The MCP server communicates over stdio. Any `console.log` writes to stdout and interleaves plain text with JSON-RPC frames, causing the MCP client to receive malformed messages — failures are silent. All logging in `src/mcp-server.ts` must use `process.stderr.write("[tag] message\n")` exclusively.

### build.sh builds three targets
`src/build.sh` compiles `capture-system-audio`, `capture-mic-audio`, and `detect-meeting`. All require Xcode Command Line Tools and macOS 13+. The system audio target requires Screen Recording permission at runtime; the mic target requires Microphone permission; detect-meeting requires no new permissions.

### SPM executable targets cannot embed Info.plist as a resource
Adding `Info.plist` to an SPM `.executableTarget`'s `resources` array fails with: "resource 'Info.plist' is forbidden; Info.plist is not supported as a top-level resource file in the resources bundle." This applies to both `.copy()` and `.process()`. For the `app/` Menu Bar app, `LSUIElement` behavior is achieved via `NSApplication.shared.setActivationPolicy(.accessory)` in `main.swift` — not via plist. The `Info.plist` is excluded in Package.swift (`exclude: ["Info.plist"]`) and kept in source only for documentation.

### DispatchSource on a directory fires for new entries, not for file content changes
`DispatchSource.makeFileSystemObjectSource` with `eventMask: .write` on a **directory** fires when the directory's contents change (files or subdirectories are added or removed). It does NOT fire when files inside the directory have their content updated. If you want to detect that a specific file was updated (e.g. an atomic write via rename), open the **file** with `O_EVTONLY` directly. This distinction matters for daemon integration: watching `data/transcriptions/` detects new session directories, but watching `data/.daemon-status.json` must open the file itself to detect writes.

### NSWorkspace requires AppKit, not just Foundation
Using `NSWorkspace.shared.runningApplications` in a Swift binary compiled with only `-framework Foundation` will produce a linker error: `Undefined symbol: _OBJC_CLASS_$_NSWorkspace`. Always add `-framework AppKit` to the swiftc invocation. This is easy to miss because NSWorkspace headers are available via Foundation imports — the failure only appears at link time.

## Fractal tree

This repo uses a fractal predicate tree in `.fractal/` for project management.
Run `bash scripts/fractal-tree.sh` to see current state.
For project context, read `conclusion.md` files from satisfied nodes.
See `references/context-protocol.md` in the fractal plugin for the full navigation protocol.
