/**
 * transcribe-session.ts — Session orchestrator
 *
 * Spawns the audio capture process and transcribes each chunk as it arrives.
 *
 * Usage:
 *   bun run src/transcribe-session.ts [--capture mic|system]
 *
 * Environment:
 *   OPENAI_API_KEY — required (passed through to transcribeChunk)
 *
 * IPC protocol (from docs/audio-contract.md):
 *   READY              → capture started
 *   CHUNK:<path>       → new chunk ready, transcribe it
 *   ERROR:<desc>       → non-fatal error, log and continue
 *   DONE               → capture shut down, session complete
 *
 * Shutdown:
 *   Send SIGTERM to this process → forwards SIGTERM to capture child.
 *   Swift finishes its current chunk, writes DONE, exits 0.
 *   The read loop naturally ends when DONE arrives.
 */

import { transcribeChunk } from "./transcribe";

type CaptureType = "mic" | "system";

function parseCaptureArg(): CaptureType {
  const idx = process.argv.indexOf("--capture");
  if (idx !== -1 && process.argv[idx + 1]) {
    const val = process.argv[idx + 1];
    if (val === "mic" || val === "system") return val;
  }
  return "system";
}

async function readLines(
  stream: ReadableStream<Uint8Array>,
  onLine: (line: string) => Promise<void>
): Promise<void> {
  const decoder = new TextDecoder();
  const reader = stream.getReader();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed) {
          await onLine(trimmed);
        }
      }
    }
    // Handle any remaining buffer content
    if (buffer.trim()) {
      await onLine(buffer.trim());
    }
  } finally {
    reader.releaseLock();
  }
}

async function main() {
  const captureType = parseCaptureArg();
  const sessionId = `session-${Date.now()}`;

  const captureCmd =
    captureType === "mic"
      ? ["./src/capture-mic-audio"]
      : ["./src/capture-system-audio"];

  console.log(`[session] starting — id=${sessionId} capture=${captureType}`);

  const capture = Bun.spawn(captureCmd, {
    stdout: "pipe",
    stderr: "inherit",
  });

  // Forward SIGTERM to the capture child
  process.on("SIGTERM", () => {
    console.log("[session] SIGTERM received — stopping capture");
    capture.kill("SIGTERM");
    // The read loop below continues until capture writes DONE and closes stdout
  });

  // Process stdout line by line
  await readLines(capture.stdout, async (line) => {
    if (line === "READY") {
      console.log("[session] capture started");
    } else if (line.startsWith("CHUNK:")) {
      const chunkPath = line.slice("CHUNK:".length).trim();
      console.log(`[session] transcribing chunk: ${chunkPath}`);
      try {
        const text = await transcribeChunk(chunkPath, sessionId);
        console.log(`[session] transcribed: ${text.slice(0, 50)}${text.length > 50 ? "..." : ""}`);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`[session] transcription error: ${message}`);
      }
    } else if (line.startsWith("ERROR:")) {
      const desc = line.slice("ERROR:".length).trim();
      console.error(`[session] capture error: ${desc}`);
    } else if (line === "DONE") {
      console.log("[session] capture done, session complete");
    }
  });

  await capture.exited;
  console.log(`[session] session ${sessionId} ended`);
}

main().catch((err) => {
  console.error("[session] fatal:", err);
  process.exit(1);
});
