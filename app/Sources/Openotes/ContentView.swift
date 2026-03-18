import SwiftUI

struct ContentView: View {
    @StateObject private var store = SessionStore()

    var body: some View {
        SessionListView(store: store)
            .frame(width: 360, height: 480)
    }
}
