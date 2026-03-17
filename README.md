# openotes

Real-time meeting transcription for macOS. Captures system audio and microphone simultaneously, converts to Whisper-optimized format, and delivers chunks for AI transcription.

## How it works

```
System Audio (ScreenCaptureKit)  ──┐
                                   ├──→  16kHz mono WAV chunks  ──→  Whisper API
Microphone (AVAudioEngine)       ──┘
```

Two native Swift CLIs capture audio from different sources, convert from hardware format (Float32 48kHz stereo) to Whisper's preferred format (Int16 16kHz mono), and write 30-second WAV chunks to disk. An IPC protocol over stdout coordinates with the orchestrator.

## Project structure

```
openotes/
├── docs/
│   └── audio-contract.md      # Chunk format & IPC protocol spec
├── spike/
│   ├── build.sh               # Spike build script
│   └── capture-audio.swift    # Initial ScreenCaptureKit proof-of-concept
├── src/
│   ├── build.sh               # Compiles both capture targets
│   ├── capture-mic-audio.swift       # Microphone capture (AVAudioEngine)
│   ├── capture-system-audio.swift    # System audio capture (ScreenCaptureKit)
│   └── validate.sh            # Output validation script
└── README.md
```

## Build

Requires macOS 13+ and Xcode Command Line Tools.

```bash
cd src && ./build.sh
```

## Usage

```bash
# Capture system audio (requires Screen Recording permission)
./src/capture-system-audio

# Capture microphone (requires Microphone permission)
./src/capture-mic-audio
```

Both binaries follow the same IPC protocol:

```
READY                          # Stream initialized
CHUNK:/tmp/openotes/.../chunk-001.wav   # New chunk written
DONE                           # Graceful shutdown (after SIGTERM)
```

Chunks are written atomically (write to `.tmp`, rename on complete) to prevent partial reads.

## Audio pipeline

1. **Capture** — Native framework taps audio at hardware sample rate
2. **Downsample** — 48kHz → 16kHz via AudioConverter with decimation
3. **Downmix** — Stereo → mono (channel averaging)
4. **Requantize** — Float32 → Int16 (×32767, clamped)
5. **Chunk** — 30s WAV files, ~960KB each

## Requirements

- macOS 13+ (Ventura)
- Xcode Command Line Tools
- Screen Recording permission (system audio)
- Microphone permission (mic capture)

## License

MIT
