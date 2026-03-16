import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreAudio

// MARK: - WAV Writer

class WAVWriter {
    private var fileHandle: FileHandle?
    private let url: URL
    private var dataByteCount: UInt32 = 0
    private let sampleRate: Double
    private let channelCount: UInt32
    private let bitsPerSample: UInt32 = 32 // Float32

    init(url: URL, sampleRate: Double, channelCount: UInt32) throws {
        self.url = url
        self.sampleRate = sampleRate
        self.channelCount = channelCount

        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: url)
        writeHeader()
    }

    private func writeHeader() {
        // Write placeholder header — will be finalized on close
        let header = Data(repeating: 0, count: 44)
        fileHandle?.write(header)
    }

    func write(samples: [Float]) {
        var data = Data(capacity: samples.count * 4)
        for sample in samples {
            var s = sample
            data.append(contentsOf: withUnsafeBytes(of: &s) { Array($0) })
        }
        fileHandle?.write(data)
        dataByteCount += UInt32(data.count)
    }

    func close() {
        // Seek back to start and write proper WAV header
        fileHandle?.seek(toFileOffset: 0)

        let byteRate = UInt32(sampleRate) * channelCount * (bitsPerSample / 8)
        let blockAlign = UInt16(channelCount * (bitsPerSample / 8))
        let totalDataLen = dataByteCount
        let riffChunkSize = 36 + totalDataLen

        var header = Data()
        // RIFF chunk
        header.append(contentsOf: Array("RIFF".utf8))
        header.append(littleEndianBytes: riffChunkSize)
        header.append(contentsOf: Array("WAVE".utf8))
        // fmt sub-chunk
        header.append(contentsOf: Array("fmt ".utf8))
        header.append(littleEndianBytes: UInt32(18))           // fmt chunk size (18 for float)
        header.append(littleEndianBytes: UInt16(3))            // audio format: IEEE float
        header.append(littleEndianBytes: UInt16(channelCount))
        header.append(littleEndianBytes: UInt32(sampleRate))
        header.append(littleEndianBytes: byteRate)
        header.append(littleEndianBytes: blockAlign)
        header.append(littleEndianBytes: UInt16(bitsPerSample))
        header.append(littleEndianBytes: UInt16(0))            // extra params size
        // data sub-chunk
        header.append(contentsOf: Array("data".utf8))
        header.append(littleEndianBytes: totalDataLen)

        fileHandle?.write(header)
        fileHandle?.closeFile()
        fileHandle = nil
    }
}

extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndianBytes value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
}

// MARK: - Stream Output Delegate

@available(macOS 13.0, *)
class AudioCaptureDelegate: NSObject, SCStreamOutput, SCStreamDelegate {
    private let writer: WAVWriter
    private var sampleCount = 0

    init(writer: WAVWriter) {
        self.writer = writer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let ptr = dataPointer, length > 0 else { return }

        // Interpret raw bytes as Float32 samples
        let floatCount = length / MemoryLayout<Float>.size
        let floatPtr = UnsafeBufferPointer(start: ptr.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }, count: floatCount)
        let samples = Array(floatPtr)
        writer.write(samples: samples)
        sampleCount += samples.count
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
}

// MARK: - Main

@available(macOS 13.0, *)
func run() async {
    let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("system-audio.wav")

    print("Output: \(outputURL.path)")
    print("Requesting shareable content...")

    // Get shareable content — requires Screen Recording permission
    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
    } catch {
        print("FAIL: Could not get shareable content: \(error)")
        print("Ensure Screen Recording permission is granted in System Settings > Privacy & Security > Screen Recording.")
        exit(1)
    }

    guard let display = content.displays.first else {
        print("FAIL: No displays found.")
        exit(1)
    }

    print("Configuring stream for display: \(display.displayID)")

    let config = SCStreamConfiguration()
    config.capturesAudio = true
    config.excludesCurrentProcessAudio = false
    // Minimal video — audio-only capture still requires a video component in ScreenCaptureKit
    config.width = 2
    config.height = 2
    config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps — nearly nothing
    config.queueDepth = 8

    // Exclude no applications — capture all system audio
    let filter = SCContentFilter(display: display, excludingWindows: [])

    let writer: WAVWriter
    do {
        writer = try WAVWriter(
            url: outputURL,
            sampleRate: Double(config.sampleRate),
            channelCount: UInt32(config.channelCount)
        )
    } catch {
        print("FAIL: Could not create WAV writer: \(error)")
        exit(1)
    }

    let delegate = AudioCaptureDelegate(writer: writer)
    let stream = SCStream(filter: filter, configuration: config, delegate: delegate)

    do {
        try stream.addStreamOutput(delegate, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream.startCapture()
    } catch {
        print("FAIL: Could not start stream: \(error)")
        exit(1)
    }

    print("Capturing system audio for 10 seconds...")
    try? await Task.sleep(nanoseconds: 10_000_000_000)

    do {
        try await stream.stopCapture()
    } catch {
        print("Warning: error stopping stream: \(error)")
    }

    writer.close()

    let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
    let size = attrs?[.size] as? Int ?? 0
    if size > 44 {
        print("PASS: Captured system audio -> \(outputURL.lastPathComponent) (\(size) bytes)")
    } else {
        print("FAIL: Output file is empty or missing — no audio samples received.")
        print("Check permissions and ensure some audio is playing during capture.")
        exit(1)
    }
}

if #available(macOS 13.0, *) {
    Task {
        await run()
        exit(0)
    }
    RunLoop.main.run()
} else {
    print("FAIL: macOS 13.0+ required.")
    exit(1)
}
