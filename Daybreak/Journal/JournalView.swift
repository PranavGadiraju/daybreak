import SwiftUI

/// S8: approved reflections, newest first.
struct JournalView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.journal.entries.isEmpty {
                    ContentUnavailableView(
                        "No reflections yet",
                        systemImage: "book.closed",
                        description: Text("Your first approved reflection will appear here."))
                } else {
                    List {
                        Section {
                            ForEach(model.journal.entries) { entry in
                                NavigationLink(value: entry) {
                                    EntryRow(entry: entry)
                                }
                            }
                        } header: {
                            Text(header)
                        }
                    }
                    .navigationDestination(for: ReflectionEntry.self) { entry in
                        EntryDetailView(entry: entry)
                    }
                }
            }
            .navigationTitle("Journal")
        }
    }

    private var header: String {
        let count = model.journal.entries.count
        return "\(model.streak)-day streak · \(count) \(count == 1 ? "entry" : "entries")"
    }
}

struct EntryRow: View {
    let entry: ReflectionEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.approvedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.headline)
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(entry.approvedAt, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var preview: String {
        guard let first = entry.goals.first else { return "" }
        let more = entry.goals.count - 1
        return more > 0 ? "\(first) +\(more)" : first
    }
}

struct EntryDetailView: View {
    let entry: ReflectionEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                GoalsCard(title: "Goals", goals: entry.goals)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reflection").font(.headline)
                    Text(entry.reflection)
                }
            }
            .padding(20)
        }
        .navigationTitle(Text(entry.approvedAt, format: .dateTime.weekday(.wide).day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var meta: String {
        let time = entry.approvedAt.formatted(date: .omitted, time: .shortened)
        let tries = entry.attempts == 1 ? "first try" : "\(entry.attempts) tries"
        return "Approved \(time) · \(entry.strictness.title) bar · \(tries)"
    }
}
