import SwiftUI

struct ContentView: View {
    @StateObject private var store = SessionStore()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.largeTitle)
            Text("Openotes")
                .font(.headline)
            if store.sessions.isEmpty {
                Text("No sessions yet.")
                    .foregroundColor(.secondary)
            } else {
                Text("\(store.sessions.count) session(s) loaded")
                Text("\(store.sessions[0].segments.count) segments in latest")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 360, height: 480)
    }
}
