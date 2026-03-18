# Learnings

## daemon-integration

**DispatchSource on a file vs. directory for atomic write detection:** To detect when a file is atomically replaced (write-to-tmp + rename), open the *file itself* with `O_EVTONLY` and watch for `.write` events — not the directory containing it. Watching the directory with `.write` fires when directory contents change (file added/removed), which is correct for detecting new session subdirectories in `data/transcriptions/`. These are two different DispatchSource use cases: directory watch (transcriptions/) for new entries, file watch (.daemon-status.json) for content updates on a known file.

**Synchronous file writes for shutdown-safe status:** In a Bun process that calls `process.exit(0)` from a SIGTERM handler, any pending Promise-based I/O (e.g. `Bun.write().then(renameSync)`) may not complete before exit. For state files that must be accurate at shutdown (recording indicator), use synchronous `writeFileSync + renameSync` from Node's `fs` module. Bun supports `fs.writeFileSync` natively — no extra dependency.

## data-layer-swift

**SPM `swift run` CWD vs `Bundle.main.bundleURL` for data path resolution:** In an SPM executable, `Bundle.main.bundleURL` resolves to `.build/arm64-apple-macosx/debug/BinaryName` — deep inside the package's build directory. It is NOT the repo root or the `app/` directory. For resolving data paths at runtime, use `FileManager.default.currentDirectoryPath` instead, which gives the working directory at launch time. When running `swift run` from `app/`, CWD is `app/` — so `../data` correctly finds the repo's `data/` directory. This is the right pattern for SPM-managed macOS utilities that reference files relative to the repo root.

## scaffold-menubar-app

**SPM executables cannot embed Info.plist as a resource:** Adding `Info.plist` to an SPM `.executableTarget`'s `resources` array (via `.copy()` or `.process()`) causes a build error: "resource 'Info.plist' in target is forbidden; Info.plist is not supported as a top-level resource file in the resources bundle." The workaround for LSUIElement (no Dock icon) is to call `NSApplication.shared.setActivationPolicy(.accessory)` in `main.swift` — this is equivalent at runtime. Keep the `Info.plist` in the source tree (excluded via `exclude: ["Info.plist"]` in Package.swift) for future Xcode project integration.

**`-sectcreate` linker flag does not work via SPM `unsafeFlags`:** Attempting to embed Info.plist via `linkerSettings: [.unsafeFlags(["-sectcreate", "__TEXT", "__info_plist", "path/to/Info.plist"])]` in Package.swift fails with "unknown argument: '-sectcreate'". The linker invocation via SPM does not pass flags in the correct position for `-sectcreate`. Use `setActivationPolicy` instead.

**macOS Menu Bar app lifecycle without `@main`:** For NSStatusItem + NSPopover apps, avoid the `@main` / `App` protocol pattern — it creates a full application lifecycle with a Dock icon and window by default. Instead: (1) create `main.swift` as the SPM entry point, (2) instantiate `AppDelegate` manually, (3) set it as `NSApplication.shared.delegate`, (4) call `setActivationPolicy(.accessory)` before `run()`. This gives full control over the activation policy and avoids the SwiftUI App lifecycle conflicting with AppKit.

## impl-daemon

**`import.meta.url` for portable cwd in Bun spawns:** When a Bun script spawns a child process that needs the repo root as its working directory, avoid hardcoding the absolute path. Use `new URL("..", import.meta.url).pathname` to compute the parent directory of the current file at runtime. This works regardless of where the repo is cloned and survives renames.

**Bun stdin as ReadableStream:** `process.stdin` in Bun implements the Web Streams API when treated as `ReadableStream<Uint8Array>`. To read one line, cast with `as unknown as ReadableStream<Uint8Array>`, get a reader, read chunks until `\n` is found, then `reader.releaseLock()` before returning. The `readline` Node.js module is not needed.

**LaunchAgent plist XML must escape `&&`:** The `&&` operator in shell commands embedded in a plist `<string>` must be written as `&amp;&amp;`. Unescaped `&` causes `xmllint` parse errors and launchctl may fail to load the plist silently.

## impl-deteccao

**NSWorkspace requires AppKit, not just Foundation:** `NSWorkspace` is declared in AppKit. Importing `Foundation` alone is not sufficient — the Swift compiler resolves the type but the linker fails with `Undefined symbol: _OBJC_CLASS_$_NSWorkspace`. Always add `-framework AppKit` to the swiftc invocation when using NSWorkspace.

**osascript for browser tab URL detection does not require Accessibility permission:** Reading tab URLs from Chrome, Arc, or Edge via `tell application id "..."` does not trigger macOS Accessibility permission prompts in a non-sandboxed binary — it uses the standard AppleScript application scripting bridge (Automation permission, which is auto-granted for scripting-enabled apps by default). Safari is the exception: it uses a different tab model (`URL of current tab of w` vs. iterating `tabs of w`). Always wrap Safari URL access in `try/end try` as `current tab` may be nil on windows with no active tab.

## transcricao-ia

**`bun --check` does not exist:** Bun 1.3 has no standalone type-check command. The plan specified `bun --check src/file.ts` but this flag does not exist. Actual behavior: Bun interprets `--check` as a flag to the script runner, not as a type-check. Use `bun build <file> --outdir /tmp` as a build-time validity proxy — it catches import errors and some type issues via Bun's bundler. For full TypeScript type checking, `tsc --noEmit` requires installing typescript as a dev dependency.

**FormData re-use across retries:** In Bun, constructing a `FormData` with a `Blob` and then passing it to multiple `fetch` calls may fail silently on the second attempt if the Blob's internal stream was consumed. Always construct FormData inside the retry lambda, not outside it.

**`import.meta.main` for dual-mode modules:** Bun supports `import.meta.main` to test if a module is the entry point (analogous to `if __name__ == "__main__"` in Python or `require.main === module` in Node). Use this to guard CLI entrypoints in modules that are also imported as libraries — otherwise the CLI logic runs at import time and breaks consumers.

## mcp-server-exposicao

**`bun add openserver` installs the wrong package:** The npm registry has a 2016 package also named `openserver` (v0.2.5 — a simple web server). Running `bun add openserver` silently installs it. The correct package is `bun add github:rmolines/openserver`. Distinguish by checking exports: the correct package exports `createServer`, `defineSchema`; the wrong one exports `startServer`.

**`bun build` requires `--target bun` for openserver:** The default bundler target is browser. openserver's dist bundle imports `node:process` via a default import that the browser polyfill doesn't support. Building without `--target bun` produces a hard error. Always use `bun build src/mcp-server.ts --outdir /tmp/check --target bun`.

**`console.log` corrupts MCP stdio — use `process.stderr.write`:** MCP stdio transport uses stdout for JSON-RPC frames. Any `console.log` call interleaves plain text with the protocol, causing the client to receive malformed messages. Failures are silent (client disconnects or gets parse errors). All internal logging must go to stderr.

## captura-microfone

**AVAudioEngine tap buffer layout:** `AVAudioPCMBuffer.floatChannelData` returns a non-interleaved layout — each channel has its own pointer (`channelData[0]`, `channelData[1]`, etc.). This is the opposite of ScreenCaptureKit's raw interleaved bytes. When reusing an `AudioConverter` designed for interleaved input, you must manually interleave the per-channel arrays before passing to the converter.

**Hardware format tap:** Always pass `inputNode.inputFormat(forBus: 0)` as the tap format. Passing `nil` or a different format causes AVAudioEngine to insert a converter node internally, which can fail silently or produce wrong sample counts. Reading the hardware format first and using it directly is the safe pattern.

**Decimation ratio at runtime:** Microphone hardware rate varies by Mac model (44.1kHz on some older models, 48kHz on newer ones). Computing the decimation ratio dynamically from the actual hardware rate (`max(1, Int((hardwareSampleRate / 16000.0).rounded()))`) handles both cases without hardcoding.
