import Foundation

struct TranscriptionSegment: Codable, Identifiable {
    var id: Int { seq }
    let text: String
    let timestamp: Int
    let seq: Int
    let duration_ms: Int
    // chunk_path is ignored intentionally

    enum CodingKeys: String, CodingKey {
        case text, timestamp, seq, duration_ms
    }
}

struct Session: Identifiable {
    let id: String          // directory name: "session-<timestamp>"
    let date: Date          // parsed from the numeric timestamp suffix (milliseconds)
    var segments: [TranscriptionSegment]
    var sourceAppName: String?
}
