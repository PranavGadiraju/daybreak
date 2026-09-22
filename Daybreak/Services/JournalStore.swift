import Foundation
import Observation

/// One approved reflection.
nonisolated struct ReflectionEntry: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var day: DayKey
    var approvedAt: Date
    var goals: [String]
    var reflection: String
    var strictness: Strictness
    /// How many times "Done reflecting" was tapped before the draft cleared the bar, counting the successful tap.
    var attempts: Int
}

/// Approved reflections, newest first, as one JSON file in the app group container.
@Observable
final class JournalStore {
    private(set) var entries: [ReflectionEntry] = []
    private let fileURL: URL

    init(directory: URL? = AppGroup.containerURL) {
        fileURL = Self.fileURL(in: directory)
        load()
    }

    static func fileURL(in directory: URL? = AppGroup.containerURL) -> URL {
        (directory ?? URL.documentsDirectory).appending(path: "journal.json")
    }

    func entry(for day: DayKey) -> ReflectionEntry? {
        entries.first { $0.day == day }
    }

    func append(_ entry: ReflectionEntry) {
        entries.removeAll { $0.day == entry.day }
        entries.insert(entry, at: 0)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            entries = try decoder.decode([ReflectionEntry].self, from: data)
                .sorted { $0.approvedAt > $1.approvedAt }
        } catch {
            Log.app.error("Journal could not be read: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(entries).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            Log.app.error("Journal could not be saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Consecutive days with an approved entry, counting back from today, or from yesterday if today has none yet.
nonisolated enum JournalStreak {
    static func count(days: Set<DayKey>, today: Date, calendar: Calendar = .current) -> Int {
        var cursor = today
        if !days.contains(DayKey(cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(DayKey(cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
