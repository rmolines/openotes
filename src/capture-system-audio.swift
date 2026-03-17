import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

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

/// Converts ScreenCaptureKit Float32 interleaved stereo 48kHz → Int16 mono 16kHz.
struct AudioConverter {
    /// - Parameters:
    ///   - interleavedFloat32: raw interleaved samples (L, R, L, R, …) at 48kHz
    ///   - channelCount: number of channels in the input (expected: 2)
    /// - Returns: mono 16-bit PCM samples at 16kHz
    func convert(interleavedFloat32 samples: [Float], channelCount: Int) -> [Int16] {
        guard !samples.isEmpty else { return [] }

        let ch = max(channelCount, 1)

        // Step 1 — Downmix: interleaved → mono Float32 at 48kHz
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

        // Step 2 — Low-pass filter (3-tap: [0.25, 0.5, 0.25]) then decimate by 3
        // Decimation factor 3: 48kHz / 3 = 16kHz
        let decimFactor = 3
        let outputCount = frameCount / decimFactor
        var int16Out = [Int16](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let center = i * decimFactor
            // 3-tap moving average low-pass filter applied at the decimation point
            let s0: Float = center > 0 ? mono[center - 1] : mono[center]
            let s1: Float = mono[center]
            let s2: Float = center + 1 < frameCount ? mono[center + 1] : mono[center]
            let filtered = 0.25 * s0 + 0.5 * s1 + 0.25 * s2

            // Step 3 — Requantize: Float32 → Int16
            let scaled = filtered * 32767.0
            let clamped = max(-32768.0, min(32767.0, scaled))
            int16Out[i] = Int16(clamped)
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

// MARK: - Audio Capture Delegate

@available(macOS 13.0, *)
class AudioCaptureDelegate: NSObject, SCStreamOutput, SCStreamDelegate {
    private let converter = AudioConverter()
    private let chunkManager: ChunkManager
    var shouldStop = false

    init(chunkManager: ChunkManager) {
        self.chunkManager = chunkManager
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio else { return }
        guard !shouldStop else { return }
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard let ptr = dataPointer, length > 0 else { return }

        // Interpret raw bytes as interleaved Float32 samples (48kHz stereo from SCK)
        let floatCount = length / MemoryLayout<Float>.size
        let floatPtr = UnsafeBufferPointer(
            start: ptr.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 },
            count: floatCount
        )
        let samples = Array(floatPtr)

        // Determine channel count from the format description
        let channelCount: Int
        if let fmtDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc) {
            channelCount = Int(asbd.pointee.mChannelsPerFrame)
        } else {
            channelCount = 2  // default: stereo
        }

        let int16Samples = converter.convert(interleavedFloat32: samples, channelCount: channelCount)
        chunkManager.feed(int16Samples)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("ERROR:Stream stopped with error: \(error.localizedDescription)")
        fflush(stdout)
    }

    func flush() {
        chunkManager.flush()
    }
}

// MARK: - Main

@available(macOS 13.0, *)
func run() async {
    let chunksDir = URL(fileURLWithPath: "/tmp/openotes/chunks")

    // Create chunks directory, clearing any existing files
    do {
        if FileManager.default.fileExists(atPath: chunksDir.path) {
            let existing = try FileManager.default.contentsOfDirectory(
                at: chunksDir,
                includingPropertiesForKeys: nil
            )
            for file in existing {
                try? FileManager.default.removeItem(at: file)
            }
        } else {
            try FileManager.default.createDirectory(
                at: chunksDir,
                withIntermediateDirectories: true
            )
        }
    } catch {
        print("ERROR:Could not prepare chunks directory: \(error.localizedDescription)")
        fflush(stdout)
        exit(1)
    }

    // Get shareable content — requires Screen Recording permission
    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
    } catch {
        print("ERROR:Could not get shareable content: \(error.localizedDescription)")
        fflush(stdout)
        exit(1)
    }

    guard let display = content.displays.first else {
        print("ERROR:No displays found")
        fflush(stdout)
        exit(1)
    }

    let config = SCStreamConfiguration()
    config.capturesAudio = true
    config.excludesCurrentProcessAudio = false
    // Minimal video — ScreenCaptureKit requires a video component even for audio-only capture
    config.width = 2
    config.height = 2
    config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 fps
    config.queueDepth = 8

    let filter = SCContentFilter(display: display, excludingWindows: [])

    let chunkManager = ChunkManager(chunksDir: chunksDir)
    let delegate = AudioCaptureDelegate(chunkManager: chunkManager)
    let stream = SCStream(filter: filter, configuration: config, delegate: delegate)

    do {
        try stream.addStreamOutput(
            delegate,
            type: .audio,
            sampleHandlerQueue: .global(qos: .userInteractive)
        )
        try await stream.startCapture()
    } catch {
        print("ERROR:Could not start stream: \(error.localizedDescription)")
        fflush(stdout)
        exit(1)
    }

    print("READY")
    fflush(stdout)

    // Install SIGTERM handler for graceful shutdown
    let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    signal(SIGTERM, SIG_IGN)  // tell the OS we're handling it ourselves
    sigSource.setEventHandler {
        delegate.shouldStop = true
        delegate.flush()
        print("DONE")
        fflush(stdout)
        exit(0)
    }
    sigSource.resume()

    // Run indefinitely — terminated by SIGTERM handler above.
    // The top-level RunLoop.main.run() keeps the process alive.
    await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in
        // Never resumes — process exits via exit(0) in the SIGTERM handler
    }
}

if #available(macOS 13.0, *) {
    Task {
        await run()
    }
    RunLoop.main.run()
} else {
    print("ERROR:macOS 13.0+ required")
    fflush(stdout)
    exit(1)
}
