import Foundation
import Combine

class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []

    private var dataDir: URL {
        if let envPath = ProcessInfo.processInfo.environment["OPENOTES_DATA_DIR"] {
            return URL(fileURLWithPath: envPath)
        }
        // Fallback: ../data relative to CWD (works with `swift run` from app/)
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.deletingLastPathComponent().appendingPathComponent("data")
    }

    private var transcriptionsDirSource: DispatchSourceFileSystemObject?
    private var transcriptionsDirFd: Int32 = -1

    init() {
        load()
        startWatching()
    }

    private func startWatching() {
        let transcriptionsURL = dataDir.appendingPathComponent("transcriptions")
        // Ensure the directory exists before opening
        try? FileManager.default.createDirectory(
            at: transcriptionsURL,
            withIntermediateDirectories: true
        )
        let path = transcriptionsURL.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        transcriptionsDirFd = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.resume()
        transcriptionsDirSource = source
    }

    deinit {
        transcriptionsDirSource?.cancel()
        if transcriptionsDirFd >= 0 {
            close(transcriptionsDirFd)
        }
    }

    func load() {
        let transcriptionsDir = dataDir.appendingPathComponent("transcriptions")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: transcriptionsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }

        let decoder = JSONDecoder()
        var loaded: [Session] = []

        for entry in entries where entry.lastPathComponent.hasPrefix("session-") {
            let sessionId = entry.lastPathComponent
            // Parse date from "session-<ms>"
            let tsString = sessionId.replacingOccurrences(of: "session-", with: "")
            let date: Date
            if let ms = Double(tsString) {
                date = Date(timeIntervalSince1970: ms / 1000.0)
            } else {
                date = Date()
            }

            // Load all JSON segment files
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: entry,
                includingPropertiesForKeys: nil
            ) else { continue }

            let jsonFiles = files
                .filter { $0.pathExtension == "json" }
                .sorted { a, b in
                    let aSeq = Int(a.deletingPathExtension().lastPathComponent) ?? 0
                    let bSeq = Int(b.deletingPathExtension().lastPathComponent) ?? 0
                    return aSeq < bSeq
                }

            var segments: [TranscriptionSegment] = []
            for file in jsonFiles {
                guard let data = try? Data(contentsOf: file),
                      let seg = try? decoder.decode(TranscriptionSegment.self, from: data)
                else { continue }
                segments.append(seg)
            }

            loaded.append(Session(
                id: sessionId,
                date: date,
                segments: segments,
                sourceAppName: nil
            ))
        }

        // Sort descending by date (newest first)
        sessions = loaded.sorted { $0.date > $1.date }
    }
}
