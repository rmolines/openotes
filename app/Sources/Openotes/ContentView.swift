import SwiftUI

struct ContentView: View {
    @StateObject private var store = SessionStore()

    var body: some View {
        NavigationStack {
            SessionListView(store: store)
        }
        .frame(width: 360, height: 480)
    }
}
