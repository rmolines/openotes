# Audio Chunk Contract

## Overview

openotes captures system audio from meetings and delivers it in chunks to the Whisper API for transcription. This document defines the format, delivery mechanism, and protocol between the Swift capture process and the Bun/TS orchestrator.

## Chunk Format

| Field         | Value                              |
|---------------|------------------------------------|
| Container     | WAV (RIFF)                         |
| Codec         | PCM 16-bit signed integer (s16le)  |
| Sample rate   | 16000 Hz                           |
| Channels      | 1 (mono)                           |
| Bit depth     | 16                                 |
| Byte rate     | 32000 bytes/sec                    |
| Duration      | 30 seconds                         |
| File size     | ~960 KB per chunk                  |
| Naming        | `chunk-{unix_ms}-{seq}.wav`        |

### Why these values?

- **16kHz mono**: Whisper's native sample rate. Avoids resampling and reduces file size.
- **16-bit PCM**: Whisper's preferred format. No quality loss vs float32 for speech.
- **30 seconds**: Long enough for context, short enough for low latency (~30s delay).
- **WAV**: No encoding overhead, universally supported, trivial to write.

### Conversion from capture

ScreenCaptureKit outputs Float32 PCM at 48kHz stereo. The Swift capture process converts:

1. **Downsample**: 48kHz → 16kHz (factor 3, simple decimation with low-pass filter)
2. **Downmix**: Stereo → mono (average L+R channels)
3. **Requantize**: Float32 → Int16 (multiply by 32767, clamp)

## IPC Protocol (Swift → Bun)

### Lifecycle

```
Bun spawns Swift process as child process
  ↓
Swift initializes ScreenCaptureKit stream
  ↓
Swift writes "READY\n" to stdout
  ↓
[capture loop - writes chunks to disk, signals on stdout]
  ↓
Bun sends SIGTERM
  ↓
Swift finishes current chunk, writes "DONE\n", exits 0
```

### Stdout protocol

The Swift process communicates via newline-delimited messages on stdout:

| Message               | Meaning                                    |
|-----------------------|--------------------------------------------|
| `READY`               | Stream initialized, capture started        |
| `CHUNK:<path>`        | New chunk written at `<path>`              |
| `ERROR:<description>` | Non-fatal error (e.g., permission issue)   |
| `DONE`                | Graceful shutdown complete                 |

Example stream:

```
READY
CHUNK:/tmp/openotes/chunks/chunk-1710600000000-001.wav
CHUNK:/tmp/openotes/chunks/chunk-1710600030000-002.wav
CHUNK:/tmp/openotes/chunks/chunk-1710600060000-003.wav
DONE
```

### File delivery

- Chunks are written to `/tmp/openotes/chunks/`
- Directory is created by the Swift process on startup
- Each chunk is written atomically (write to `.tmp`, then rename)
- Bun is responsible for cleanup after processing

### Start

```typescript
const capture = Bun.spawn(["./spike/capture-audio"], {
  stdout: "pipe",
  stderr: "inherit",
});
```

### Stop

```typescript
capture.kill("SIGTERM");
// Swift finishes current chunk, writes DONE, exits 0
```

## Consumer: Whisper API

- Endpoint: `POST https://api.openai.com/v1/audio/transcriptions`
- Model: `whisper-1`
- Max file size: 25 MB (our chunks are ~960 KB)
- Supported formats: wav, mp3, m4a, etc.
- Response: JSON with `text` field

Each 30s chunk produces a transcription segment that is stored and indexed.

## Future considerations

- **Streaming transcription** (Deepgram): Would change chunk duration to ~1-5s and use raw PCM over websocket instead of WAV files.
- **Compression** (opus/mp3): Could reduce chunk size 5-10x for remote transcription.
- **Voice Activity Detection**: Skip silent chunks to reduce API costs.
