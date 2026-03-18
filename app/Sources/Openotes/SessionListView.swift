import SwiftUI

struct SessionListView: View {
    @ObservedObject var store: SessionStore

    private var groupedSessions: [(String, [Session])] {
        let calendar = Calendar.current
        var groups: [Date: [Session]] = [:]
        for session in store.sessions {
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
        if store.sessions.isEmpty {
            VStack(spacing: 8) {
                Text("Openotes")
                    .font(.headline)
                Spacer()
                Text("No sessions yet.")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        } else {
            VStack(spacing: 0) {
                Text("Openotes")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Divider()
                List {
                    ForEach(groupedSessions, id: \.0) { (dayLabel, sessions) in
                        Section(header: Text(dayLabel).font(.subheadline).fontWeight(.semibold)) {
                            ForEach(sessions) { session in
                                SessionRowView(session: session)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
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
