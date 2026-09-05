import Foundation

enum EventColor: String, Codable, CaseIterable, Identifiable {
    case gray, blue, green, orange, red
    var id: String { rawValue }
}

struct CalendarEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    // Civil dates intentionally do not move when the user's time zone changes.
    var day: String
    var color: EventColor = .gray
    var important = false
}

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var completedDays: Set<String> = []
}

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String = ""
    var body: String = ""
    var updatedAt = Date()
    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : title }
}

enum HabitPeriod: String, CaseIterable, Codable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self { case .day: .day; case .week: .weekOfYear; case .month: .month; case .year: .year }
    }
    func days(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return [] }
        var days: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return days
    }
}

struct LifeState: Codable, Equatable {
    var events: [CalendarEvent] = []
    var habits: [Habit] = []
    var notes: [Note] = []
    var habitPeriod: HabitPeriod = .week
    var showHabitHistory = true
}

final class LifeStore {
    private let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> LifeState {
        guard FileManager.default.fileExists(atPath: url.path) else { return LifeState() }
        return try JSONDecoder().decode(LifeState.self, from: Data(contentsOf: url))
    }
    func save(_ state: LifeState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
