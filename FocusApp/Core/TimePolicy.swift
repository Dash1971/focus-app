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
    static func activityDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "—" }
        let total = Int(min(Double(Int.max / 2), max(0, seconds)))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    static let unlockDurations = [30, 60, 300, 600, 900, 1500, 1800, 2700, 3600, 7200]
    static let waitDurations = [0, 10, 20, 30, 45, 60]
    static func validDuration(_ seconds: Int) -> Bool { unlockDurations.contains(seconds) }

    static func yearProgress(at date: Date, calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: .year, for: date) else { return 0 }
        return min(1, max(0, date.timeIntervalSince(interval.start) / interval.duration))
    }

    static func yearProgress(from startYear: Int, at date: Date, calendar: Calendar = .current) -> Double {
        // The labels are Gregorian years even when the device uses a Japanese,
        // Buddhist, or other non-Gregorian display calendar. Using
        // Calendar.current here can interpret 2026 as a year in that calendar
        // and clamp a current-date result to zero.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        guard let start = gregorian.date(from: DateComponents(year: startYear, month: 1, day: 1)),
              let end = gregorian.date(from: DateComponents(year: startYear + 1, month: 1, day: 1)),
              end > start else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
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
        if seconds < 60 { return "\(seconds) sec" }
        if seconds == 3600 { return "1 hour" }
        if seconds.isMultiple(of: 3600) { return "\(seconds / 3600) hours" }
        return "\(seconds / 60) min"
    }
}
