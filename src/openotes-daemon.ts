/**
 * openotes-daemon.ts — Background daemon for meeting detection and recording
 *
 * Orchestrates detect-meeting, macOS notifications, and transcribe-session.
 *
 * Usage:
 *   bun run src/openotes-daemon.ts
 *
 * Flow:
 *   1. Spawns ./src/detect-meeting (polls every 3s)
 *   2. On MEETING_DETECTED:<source>: sends macOS notification + prompts user
 *   3. On user confirmation: spawns transcribe-session
 *   4. On MEETING_ENDED: sends SIGTERM to transcribe-session
 *   5. If detect-meeting crashes: respawns after 2s
 *
 * Logging:
 *   All logs via process.stderr.write — stdout is reserved for MCP protocol
 */

import { renameSync } from "fs";

type SubProcess = ReturnType<typeof Bun.spawn>;

let transcribeProc: SubProcess | null = null;

// ── status file ───────────────────────────────────────────────────────────────

function writeStatusFile(
  recording: boolean,
  session: string | null,
  started: string | null
): void {
  const statusPath = new URL("../data/.daemon-status.json", import.meta.url)
    .pathname;
  const tmpPath = new URL("../data/.daemon-status.json.tmp", import.meta.url)
    .pathname;
  try {
    const json = JSON.stringify({ recording, session, started });
    Bun.write(tmpPath, json).then(() => {
      try {
        renameSync(tmpPath, statusPath);
      } catch (err) {
        process.stderr.write(
          `[daemon] writeStatusFile rename failed: ${err}\n`
        );
      }
    });
  } catch (err) {
    process.stderr.write(`[daemon] writeStatusFile failed: ${err}\n`);
  }
}

// ── readline helper (copied from transcribe-session.ts pattern) ──────────────

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
    if (buffer.trim()) {
      await onLine(buffer.trim());
    }
  } finally {
    reader.releaseLock();
  }
}

// ── transcribe-session lifecycle ─────────────────────────────────────────────

function spawnTranscribeSession(): void {
  process.stderr.write("[daemon] spawning transcribe-session\n");

  transcribeProc = Bun.spawn(
    ["bun", "run", "src/transcribe-session.ts", "--capture", "system"],
    {
      stdout: "inherit",
      stderr: "inherit",
      cwd: new URL("..", import.meta.url).pathname,
    }
  );

  const sessionId = "session-" + Date.now();
  writeStatusFile(true, sessionId, new Date().toISOString());

  transcribeProc.exited.then((code) => {
    process.stderr.write(`[daemon] transcribe-session exited (code=${code})\n`);
    transcribeProc = null;
  });
}

function stopTranscribeSession(): void {
  if (transcribeProc) {
    process.stderr.write("[daemon] sending SIGTERM to transcribe-session\n");
    transcribeProc.kill("SIGTERM");
    transcribeProc = null;
    writeStatusFile(false, null, null);
  }
}

// ── notification + user prompt ───────────────────────────────────────────────

async function notifyAndAsk(source: string): Promise<boolean> {
  const script = `display dialog "Reunião detectada (${source}). Gravar?" buttons {"Não", "Gravar"} default button "Gravar" with title "openotes" giving up after 30`;
  const proc = Bun.spawn(["osascript", "-e", script], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const code = await proc.exited;
  if (code !== 0) {
    // User clicked "Não" or dialog timed out
    return false;
  }

  const output = await new Response(proc.stdout).text();
  return output.includes("Gravar");
}

// ── event handler ─────────────────────────────────────────────────────────────

async function handleEvent(line: string): Promise<void> {
  if (line.startsWith("MEETING_DETECTED:")) {
    const source = line.slice("MEETING_DETECTED:".length).trim();
    process.stderr.write(`[daemon] meeting detected: ${source}\n`);

    if (transcribeProc !== null) {
      process.stderr.write("[daemon] already recording — skipping\n");
      return;
    }

    const confirmed = await notifyAndAsk(source);
    if (confirmed) {
      spawnTranscribeSession();
    } else {
      process.stderr.write("[daemon] user declined recording\n");
    }
  } else if (line === "MEETING_ENDED") {
    process.stderr.write("[daemon] meeting ended\n");
    stopTranscribeSession();
  } else {
    process.stderr.write(`[daemon] unknown event: ${line}\n`);
  }
}

// ── detect-meeting loop (with respawn) ───────────────────────────────────────

async function runDetectMeeting(): Promise<void> {
  while (true) {
    process.stderr.write("[daemon] starting detect-meeting\n");

    const proc = Bun.spawn(["./src/detect-meeting"], {
      stdout: "pipe",
      stderr: "inherit",
    });

    await readLines(proc.stdout, handleEvent);

    const code = await proc.exited;
    process.stderr.write(
      `[daemon] detect-meeting exited (code=${code}), respawning in 2s\n`
    );
    await Bun.sleep(2000);
  }
}

// ── SIGTERM handler ───────────────────────────────────────────────────────────

process.on("SIGTERM", () => {
  process.stderr.write("[daemon] SIGTERM received — shutting down\n");
  stopTranscribeSession();
  process.exit(0);
});

// ── main ──────────────────────────────────────────────────────────────────────

process.stderr.write("[daemon] openotes daemon starting\n");
writeStatusFile(false, null, null);
runDetectMeeting().catch((err) => {
  process.stderr.write(`[daemon] fatal: ${err}\n`);
  process.exit(1);
});
