import Foundation
import AVFoundation

// MARK: - Data Extension

extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndianBytes value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
}

// MARK: - WAV Writer

/// Writes 16-bit PCM mono WAV files at 16kHz.
/// Files are written atomically: samples are buffered to a .tmp file, then renamed on close.
class WAVWriter {
    private var fileHandle: FileHandle?
    private let finalURL: URL
    private let tmpURL: URL
    private var dataByteCount: UInt32 = 0

    private let sampleRate: UInt32 = 16000
    private let channelCount: UInt32 = 1
    private let bitsPerSample: UInt32 = 16

    init(outputURL: URL) throws {
        self.finalURL = outputURL
        self.tmpURL = outputURL.deletingPathExtension().appendingPathExtension("tmp")

        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: tmpURL)
        writePlaceholderHeader()
    }

    private func writePlaceholderHeader() {
        // 44-byte placeholder — overwritten on close
        fileHandle?.write(Data(repeating: 0, count: 44))
    }

    func write(samples: [Int16]) {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            var s = sample.littleEndian
            Swift.withUnsafeBytes(of: &s) { data.append(contentsOf: $0) }
        }
        fileHandle?.write(data)
        dataByteCount += UInt32(data.count)
    }

    /// Finalizes the WAV header, closes the tmp file, and renames it to the final path.
    func close() {
        fileHandle?.seek(toFileOffset: 0)

        let byteRate = sampleRate * channelCount * (bitsPerSample / 8)   // 32000
        let blockAlign = UInt16(channelCount * (bitsPerSample / 8))       // 2
        let riffChunkSize = 36 + dataByteCount

        var header = Data()
        // RIFF chunk descriptor
        header.append(contentsOf: Array("RIFF".utf8))
        header.append(littleEndianBytes: riffChunkSize)
        header.append(contentsOf: Array("WAVE".utf8))
        // fmt sub-chunk (PCM — size 16, no extra params)
        header.append(contentsOf: Array("fmt ".utf8))
        header.append(littleEndianBytes: UInt32(16))           // fmt chunk size: 16 for PCM
        header.append(littleEndianBytes: UInt16(1))            // audio format: 1 = PCM
        header.append(littleEndianBytes: UInt16(channelCount))
        header.append(littleEndianBytes: sampleRate)
        header.append(littleEndianBytes: byteRate)
        header.append(littleEndianBytes: blockAlign)
        header.append(littleEndianBytes: UInt16(bitsPerSample))
        // data sub-chunk
        header.append(contentsOf: Array("data".utf8))
        header.append(littleEndianBytes: dataByteCount)

        fileHandle?.write(header)
        fileHandle?.closeFile()
        fileHandle = nil

        // Atomic rename: tmp → final
        do {
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: tmpURL, to: finalURL)
        } catch {
            print("ERROR:WAVWriter rename failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Audio Converter

/// Converts AVAudioEngine Float32 samples at hardware rate → Int16 mono 16kHz.
struct AudioConverter {
    /// - Parameters:
    ///   - samples: interleaved Float32 samples at hardware sample rate
    ///   - channelCount: number of channels in the input
    ///   - hardwareSampleRate: native sample rate of the input (e.g. 48000, 44100)
    /// - Returns: mono 16-bit PCM samples at 16kHz
    func convert(samples: [Float], channelCount: Int, hardwareSampleRate: Double) -> [Int16] {
        guard !samples.isEmpty else { return [] }

        let ch = max(channelCount, 1)

        // Step 1 — Downmix: interleaved → mono Float32 at hardware rate
        let frameCount = samples.count / ch
        var mono = [Float](repeating: 0, count: frameCount)
        if ch == 1 {
            mono = samples
        } else {
            for i in 0..<frameCount {
                var sum: Float = 0
                for c in 0..<ch {
                    sum += samples[i * ch + c]
                }
                mono[i] = sum / Float(ch)
            }
        }

        // Step 2 — Decimate to 16kHz (intRatio=1 means no decimation — just requantize)
        let intRatio = max(1, Int((hardwareSampleRate / 16000.0).rounded()))
        let outputCount = frameCount / intRatio
        var int16Out = [Int16](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let center = i * intRatio
            // 3-tap low-pass filter at the decimation point
            let s0: Float = center > 0 ? mono[center - 1] : mono[center]
            let s1: Float = mono[center]
            let s2: Float = center + 1 < frameCount ? mono[center + 1] : mono[center]
            let filtered = 0.25 * s0 + 0.5 * s1 + 0.25 * s2

            // Step 3 — Requantize: Float32 → Int16
            let clamped = max(-1.0, min(1.0, filtered))
            int16Out[i] = Int16(clamped * 32767.0)
        }

        return int16Out
    }
}

// MARK: - Chunk Manager

/// Accumulates converted Int16 samples and writes 30-second WAV chunks.
class ChunkManager {
    private let targetSamples = 480_000   // 30s × 16kHz
    private let chunksDir: URL

    private var buffer = [Int16]()
    private var sequenceCounter = 1

    init(chunksDir: URL) {
        self.chunksDir = chunksDir
        buffer.reserveCapacity(targetSamples + 16384)
    }

    /// Feed converted samples. Flushes complete chunks automatically.
    func feed(_ samples: [Int16]) {
        buffer.append(contentsOf: samples)
        while buffer.count >= targetSamples {
            let chunk = Array(buffer.prefix(targetSamples))
            buffer.removeFirst(targetSamples)
            writeChunk(samples: chunk)
        }
    }

    /// Flush remaining samples as a partial chunk (called on SIGTERM).
    func flush() {
        guard !buffer.isEmpty else { return }
        writeChunk(samples: buffer)
        buffer.removeAll()
    }

    private func writeChunk(samples: [Int16]) {
        let unixMs = Int64(Date().timeIntervalSince1970 * 1000)
        let seq = String(format: "%03d", sequenceCounter)
        let filename = "chunk-\(unixMs)-\(seq).wav"
        let outputURL = chunksDir.appendingPathComponent(filename)

        sequenceCounter += 1

        do {
            let writer = try WAVWriter(outputURL: outputURL)
            writer.write(samples: samples)
            writer.close()
            print("CHUNK:\(outputURL.path)")
            fflush(stdout)
        } catch {
            print("ERROR:Failed to write chunk \(filename): \(error.localizedDescription)")
            fflush(stdout)
        }
    }
}

// MARK: - Microphone Capture

/// Manages AVAudioEngine microphone capture and feeds samples to ChunkManager.
class MicCapture {
    private let engine = AVAudioEngine()
    private let converter = AudioConverter()
    private let chunkManager: ChunkManager
    var shouldStop = false

    init(chunkManager: ChunkManager) {
        self.chunkManager = chunkManager
    }

    func start() throws {
        let inputNode = engine.inputNode
        // Use the hardware's native format to avoid format mismatch errors
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        let hardwareSampleRate = hardwareFormat.sampleRate
        let hardwareChannels = Int(hardwareFormat.channelCount)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard !self.shouldStop else { return }

            // Extract interleaved Float32 samples from the buffer
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)

            var interleaved = [Float](repeating: 0, count: frameCount * channelCount)
            if channelCount == 1 {
                // Mono: copy directly
                let ptr = channelData[0]
                for i in 0..<frameCount {
                    interleaved[i] = ptr[i]
                }
            } else {
                // Multi-channel: interleave channels
                for ch in 0..<channelCount {
                    let ptr = channelData[ch]
                    for i in 0..<frameCount {
                        interleaved[i * channelCount + ch] = ptr[i]
                    }
                }
            }

            let int16Samples = self.converter.convert(
                samples: interleaved,
                channelCount: hardwareChannels,
                hardwareSampleRate: hardwareSampleRate
            )
            self.chunkManager.feed(int16Samples)
        }

        try engine.start()
    }

    func flush() {
        chunkManager.flush()
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}

// MARK: - Main

let chunksDir = URL(fileURLWithPath: "/tmp/openotes/mic-chunks")

// Create mic-chunks directory
do {
    try FileManager.default.createDirectory(
        at: chunksDir,
        withIntermediateDirectories: true
    )
} catch {
    print("ERROR:Could not prepare mic-chunks directory: \(error.localizedDescription)")
    fflush(stdout)
    exit(1)
}

let chunkManager = ChunkManager(chunksDir: chunksDir)
let micCapture = MicCapture(chunkManager: chunkManager)

do {
    try micCapture.start()
} catch {
    print("ERROR:Could not start microphone capture: \(error.localizedDescription)")
    fflush(stdout)
    exit(1)
}

print("READY")
fflush(stdout)

// Install SIGTERM handler for graceful shutdown
let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signal(SIGTERM, SIG_IGN)  // tell the OS we're handling it ourselves
sigSource.setEventHandler {
    micCapture.shouldStop = true
    micCapture.flush()
    micCapture.stop()
    print("DONE")
    fflush(stdout)
    exit(0)
}
sigSource.resume()

// Run indefinitely — terminated by SIGTERM handler above.
RunLoop.main.run()
