# Learnings

## captura-microfone

**AVAudioEngine tap buffer layout:** `AVAudioPCMBuffer.floatChannelData` returns a non-interleaved layout — each channel has its own pointer (`channelData[0]`, `channelData[1]`, etc.). This is the opposite of ScreenCaptureKit's raw interleaved bytes. When reusing an `AudioConverter` designed for interleaved input, you must manually interleave the per-channel arrays before passing to the converter.

**Hardware format tap:** Always pass `inputNode.inputFormat(forBus: 0)` as the tap format. Passing `nil` or a different format causes AVAudioEngine to insert a converter node internally, which can fail silently or produce wrong sample counts. Reading the hardware format first and using it directly is the safe pattern.

**Decimation ratio at runtime:** Microphone hardware rate varies by Mac model (44.1kHz on some older models, 48kHz on newer ones). Computing the decimation ratio dynamically from the actual hardware rate (`max(1, Int((hardwareSampleRate / 16000.0).rounded()))`) handles both cases without hardcoding.
