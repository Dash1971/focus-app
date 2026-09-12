import Foundation

struct CountdownState: Codable, Equatable {
    var durationSeconds = 300
    var pausedRemainingSeconds = 300
    var deadline: Date?

    var isRunning: Bool { deadline != nil }

    func remaining(at date: Date = .now) -> Int {
        if let deadline {
            return max(0, Int(ceil(deadline.timeIntervalSince(date))))
        }
        return max(0, pausedRemainingSeconds)
    }
}

struct StopwatchState: Codable, Equatable {
    var elapsedBeforeRun: TimeInterval = 0
    var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    func elapsed(at date: Date = .now) -> TimeInterval {
        max(0, elapsedBeforeRun + (startedAt.map { date.timeIntervalSince($0) } ?? 0))
    }
}

struct Alarm: Identifiable, Codable, Equatable {
    var id = UUID()
    var timeMinutes: Int
    var oneTimeDate: Date?
    var repeatWeekdays: Set<Int>
    var enabled = true

    var isRepeating: Bool { !repeatWeekdays.isEmpty }

    init(
        id: UUID = UUID(),
        timeMinutes: Int,
        oneTimeDate: Date? = nil,
        repeatWeekdays: Set<Int> = [],
        enabled: Bool = true
    ) {
        self.id = id
        self.timeMinutes = min(1439, max(0, timeMinutes))
        self.oneTimeDate = oneTimeDate
        self.repeatWeekdays = Set(repeatWeekdays.filter { (1...7).contains($0) })
        self.enabled = enabled
    }

    func nextFireDate(after date: Date, calendar: Calendar = .current) -> Date? {
        guard enabled else { return nil }
        if !isRepeating {
            guard let oneTimeDate, oneTimeDate > date else { return nil }
            return oneTimeDate
        }

        let hour = timeMinutes / 60
        let minute = timeMinutes % 60
        let start = calendar.startOfDay(for: date)

        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  repeatWeekdays.contains(calendar.component(.weekday, from: day)),
                  let candidate = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: day,
                    matchingPolicy: .nextTime
                  ),
                  candidate > date else { continue }
            return candidate
        }
        return nil
    }
}

struct TimekeeperState: Codable, Equatable {
    var countdown = CountdownState()
    var stopwatch = StopwatchState()
    var alarms: [Alarm] = []
}

final class TimekeeperStore {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() throws -> TimekeeperState {
        guard FileManager.default.fileExists(atPath: url.path) else { return TimekeeperState() }
        return try JSONDecoder().decode(TimekeeperState.self, from: Data(contentsOf: url))
    }

    func save(_ state: TimekeeperState) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}

enum TimeFormat {
    static func clock(_ seconds: Int, includeHours: Bool = false) -> String {
        let safe = max(0, seconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let seconds = safe % 60
        if includeHours || hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func stopwatch(_ elapsed: TimeInterval) -> String {
        let totalHundredths = max(0, Int(elapsed * 100))
        let hours = totalHundredths / 360_000
        let minutes = (totalHundredths / 6_000) % 60
        let seconds = (totalHundredths / 100) % 60
        let hundredths = totalHundredths % 100
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, hundredths)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}
