import SwiftUI

struct SessionListView: View {
    @ObservedObject var store: SessionStore
    @State private var searchText: String = ""

    private var filteredSessions: [Session] {
        if searchText.isEmpty { return store.sessions }
        return store.sessions.filter { session in
            session.segments.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var groupedSessions: [(String, [Session])] {
        let calendar = Calendar.current
        var groups: [Date: [Session]] = [:]
        for session in filteredSessions {
            let day = calendar.startOfDay(for: session.date)
            groups[day, default: []].append(session)
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { (key, sessions) in
                let label = dayLabel(for: key, calendar: calendar)
                let sorted = sessions.sorted { $0.date > $1.date }
                return (label, sorted)
            }
    }

    var body: some View {
        Group {
            if store.sessions.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No sessions yet.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if !searchText.isEmpty && filteredSessions.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No results for \"\(searchText)\"")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(groupedSessions, id: \.0) { (dayLabel, sessions) in
                        Section(header: Text(dayLabel).font(.subheadline).fontWeight(.semibold)) {
                            ForEach(sessions) { session in
                                NavigationLink(destination: TranscriptionDetailView(session: session)) {
                                    SessionRowView(session: session)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Openotes")
        .searchable(text: $searchText, prompt: "Search transcriptions")
    }

    private func dayLabel(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack {
            Text(timeString(from: session.date))
                .font(.body)
            Spacer()
            Text("\(session.segments.count) segments")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
