import Foundation

struct UnlockDeadline: Codable, Equatable {
    let startedAt: Date
    let endsAt: Date
    let startedUptime: TimeInterval
    let duration: TimeInterval

    init(seconds: Int, now: Date = .now, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        duration = TimeInterval(seconds)
        startedAt = now
        endsAt = now.addingTimeInterval(duration)
        startedUptime = uptime
    }

    func isActive(now: Date = .now, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        // A clock rollback or reboot must never extend access. Reject a changed
        // boot epoch as well as an elapsed wall-clock or monotonic deadline.
        let elapsed = uptime - startedUptime
        let wallElapsed = now.timeIntervalSince(startedAt)
        return duration > 0 && elapsed >= 0 && elapsed < duration
            && wallElapsed >= 0 && now < endsAt && abs(wallElapsed - elapsed) < 5
    }
}

enum TimePolicy {
    static let unlockDurations = [30, 60, 300, 600, 900, 1500, 1800]
    static let waitDurations = [10, 20, 30, 45, 60]
    static func validDuration(_ seconds: Int) -> Bool { (30...86400).contains(seconds) }

    static func yearProgress(at date: Date, calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: .year, for: date) else { return 0 }
        return min(1, max(0, date.timeIntervalSince(interval.start) / interval.duration))
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        return days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
    }

    static func durationLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min"
    }
}
