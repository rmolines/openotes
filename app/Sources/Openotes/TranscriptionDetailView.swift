import SwiftUI

struct TranscriptionDetailView: View {
    let session: Session
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Title
            HStack {
                Text(sessionTitle)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Transcription
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.segments) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(timestampLabel(epochMs: segment.timestamp))
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
                .padding(16)
            }
        }
    }

    private var sessionTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d · HH:mm"
        return formatter.string(from: session.date)
    }

    private func timestampLabel(epochMs: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
