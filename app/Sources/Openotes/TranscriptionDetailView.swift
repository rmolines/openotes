import SwiftUI

struct TranscriptionDetailView: View {
    let session: Session

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(session.segments) { segment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timestampLabel(ms: segment.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(segment.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if segment.seq != session.segments.last?.seq {
                        Divider()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(sessionTitle)
    }

    private var sessionTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d · HH:mm"
        return formatter.string(from: session.date)
    }

    private func timestampLabel(ms: Int) -> String {
        let totalSeconds = ms / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "[%d:%02d:%02d]", hours, minutes, seconds)
        } else {
            return String(format: "[%02d:%02d]", minutes, seconds)
        }
    }
}
