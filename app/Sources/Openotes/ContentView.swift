import SwiftUI

struct ContentView: View {
    @StateObject private var store = SessionStore()
    @State private var selectedSession: Session? = nil

    var body: some View {
        Group {
            if let session = selectedSession {
                TranscriptionDetailView(session: session, onBack: { selectedSession = nil })
            } else {
                SessionListView(store: store, onSelect: { session in selectedSession = session })
            }
        }
        .frame(width: 360, height: 480)
    }
}
