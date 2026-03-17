/**
 * transcribe.ts — Whisper API transcription module
 *
 * Usage:
 *   bun run src/transcribe.ts <path-to-wav>
 *   echo "CHUNK:<path>" | bun run src/transcribe.ts
 *
 * Environment:
 *   OPENAI_API_KEY — required
 */

import { mkdirSync, existsSync } from "fs";
import { join } from "path";

const WHISPER_API = "https://api.openai.com/v1/audio/transcriptions";
const DEFAULT_DURATION_MS = 30000;

export interface TranscriptionResult {
  chunk_path: string;
  timestamp: number;
  seq: number;
  text: string;
  duration_ms: number;
}

/**
 * Parse chunk filename to extract session-id and seq number.
 * Expected format: chunk-{unix_ms}-{seq}.wav
 */
function parseChunkFilename(wavPath: string): { sessionId: string; seq: number } {
  const filename = wavPath.split("/").pop() ?? "";
  const match = filename.match(/^chunk-(\d+)-(\d+)\.wav$/);
  if (match) {
    return { sessionId: match[1], seq: parseInt(match[2], 10) };
  }
  // Fallback: use current timestamp as session id, 0 as seq
  return { sessionId: String(Date.now()), seq: 0 };
}

/**
 * Transcribe a WAV chunk via Whisper API and persist result.
 * Returns the transcription text.
 */
export async function transcribeChunk(wavPath: string, sessionId?: string): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    process.stderr.write("Error: OPENAI_API_KEY not set\n");
    process.exit(1);
  }

  const parsed = parseChunkFilename(wavPath);
  const effectiveSessionId = sessionId ?? parsed.sessionId;
  const seq = parsed.seq;

  // Read WAV file
  const file = Bun.file(wavPath);
  if (!(await file.exists())) {
    throw new Error(`File not found: ${wavPath}`);
  }

  const blob = await file.blob();

  // Build multipart form
  const form = new FormData();
  form.append("file", blob, wavPath.split("/").pop() ?? "audio.wav");
  form.append("model", "whisper-1");
  form.append("language", "pt");

  // Call Whisper API (retry logic added by D3 — for now throws on error)
  const response = await fetch(WHISPER_API, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: form,
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Whisper API error ${response.status}: ${body}`);
  }

  const json = (await response.json()) as { text: string };
  const text = json.text ?? "";

  // Persist result
  const dir = join("data", "transcriptions", effectiveSessionId);
  mkdirSync(dir, { recursive: true });

  const result: TranscriptionResult = {
    chunk_path: wavPath,
    timestamp: Date.now(),
    seq,
    text,
    duration_ms: DEFAULT_DURATION_MS,
  };

  const outPath = join(dir, `${seq}.json`);
  await Bun.write(outPath, JSON.stringify(result, null, 2));

  return text;
}

// CLI entrypoint
async function main() {
  // Try CLI argument first
  let wavPath = process.argv[2];

  // If no CLI arg, check stdin for CHUNK:<path>
  if (!wavPath) {
    const stdinText = await Bun.stdin.text();
    const chunkLine = stdinText.split("\n").find((l) => l.startsWith("CHUNK:"));
    if (chunkLine) {
      wavPath = chunkLine.slice("CHUNK:".length).trim();
    }
  }

  if (!wavPath) {
    process.stderr.write("Usage: bun run src/transcribe.ts <path-to-wav>\n");
    process.exit(1);
  }

  try {
    const text = await transcribeChunk(wavPath);
    process.stdout.write(text + "\n");
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    process.stderr.write(`Error: ${message}\n`);
    process.exit(1);
  }
}

main();
