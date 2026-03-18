import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.largeTitle)
            Text("Openotes")
                .font(.headline)
            Text("No sessions yet.")
                .foregroundColor(.secondary)
        }
        .frame(width: 360, height: 480)
    }
}
