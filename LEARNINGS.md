# Learnings

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
