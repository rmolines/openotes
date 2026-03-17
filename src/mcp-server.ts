import { createServer, type CustomToolDef } from "openserver";
import { z } from "zod";
import * as fs from "fs";
import * as path from "path";

const TRANSCRIPTIONS_DIR = path.join(process.cwd(), "data", "transcriptions");

interface TranscriptionSegment {
  chunk_path: string;
  timestamp: string;
  seq: number;
  text: string;
  duration_ms: number;
}

function readSegmentsForSession(sessionId: string): TranscriptionSegment[] {
  const sessionDir = path.join(TRANSCRIPTIONS_DIR, sessionId);
  if (!fs.existsSync(sessionDir)) return [];

  const files = fs
    .readdirSync(sessionDir)
    .filter((f) => f.endsWith(".json"))
    .sort((a, b) => {
      const seqA = parseInt(a.replace(".json", ""), 10);
      const seqB = parseInt(b.replace(".json", ""), 10);
      return seqA - seqB;
    });

  const segments: TranscriptionSegment[] = [];
  for (const file of files) {
    try {
      const raw = fs.readFileSync(path.join(sessionDir, file), "utf-8");
      segments.push(JSON.parse(raw) as TranscriptionSegment);
    } catch (e) {
      process.stderr.write(`[openotes] Failed to parse ${file}: ${e}\n`);
    }
  }
  return segments;
}

function listSessionIds(): string[] {
  if (!fs.existsSync(TRANSCRIPTIONS_DIR)) return [];
  return fs
    .readdirSync(TRANSCRIPTIONS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

const listSessions: CustomToolDef = {
  name: "list_sessions",
  description:
    "List all transcription sessions. Returns an array of { session_id, created_at, segment_count }.",
  inputSchema: {},
  handler: async () => {
    return listSessionIds().map((sessionId) => {
      const sessionDir = path.join(TRANSCRIPTIONS_DIR, sessionId);
      const stat = fs.statSync(sessionDir);
      const jsonFiles = fs.readdirSync(sessionDir).filter((f) => f.endsWith(".json"));
      return {
        session_id: sessionId,
        created_at: stat.mtime.toISOString(),
        segment_count: jsonFiles.length,
      };
    });
  },
};

const getSession: CustomToolDef = {
  name: "get_session",
  description:
    "Get the full transcription for a session by session_id. Returns segments ordered by seq and the full concatenated text.",
  inputSchema: {
    session_id: z.string().describe("The session ID to retrieve"),
  },
  handler: async (args: { session_id: string }) => {
    const { session_id } = args;
    const sessionDir = path.join(TRANSCRIPTIONS_DIR, session_id);
    if (!fs.existsSync(sessionDir)) {
      return { error: "Session not found" };
    }

    const segments = readSegmentsForSession(session_id);
    const full_text = segments.map((s) => s.text).join("\n");

    return {
      session_id,
      segments: segments.map((s) => ({
        seq: s.seq,
        text: s.text,
        timestamp: s.timestamp,
        duration_ms: s.duration_ms,
      })),
      full_text,
    };
  },
};

const searchTranscriptions: CustomToolDef = {
  name: "search_transcriptions",
  description:
    "Search across all transcription sessions for a query string. Returns matching segments with session_id, seq, text, and timestamp.",
  inputSchema: {
    query: z.string().describe("The text to search for (case-insensitive)"),
  },
  handler: async (args: { query: string }) => {
    const { query } = args;
    const lowerQuery = query.toLowerCase();
    const sessionIds = listSessionIds();
    const matches: Array<{
      session_id: string;
      seq: number;
      text: string;
      timestamp: string;
    }> = [];

    for (const sessionId of sessionIds) {
      const segments = readSegmentsForSession(sessionId);
      for (const segment of segments) {
        if (segment.text.toLowerCase().includes(lowerQuery)) {
          matches.push({
            session_id: sessionId,
            seq: segment.seq,
            text: segment.text,
            timestamp: segment.timestamp,
          });
        }
      }
    }

    return matches;
  },
};

const server = createServer({
  schemas: [],
  transport: "stdio",
  tools: [listSessions, getSession, searchTranscriptions],
  name: "openotes",
  version: "0.1.0",
});

await server.start();
