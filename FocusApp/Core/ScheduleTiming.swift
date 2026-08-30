import Foundation

enum ScheduleTiming {
    static func isActive(
        startMinutes: Int,
        endMinutes: Int,
        weekdays: Set<Int>,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard startMinutes != endMinutes else { return false }

        let weekday = calendar.component(.weekday, from: date)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        if endMinutes > startMinutes {
            return weekdays.contains(weekday) && minute >= startMinutes && minute < endMinutes
        }

        if minute >= startMinutes {
            return weekdays.contains(weekday)
        }

        let previousWeekday = weekday == 1 ? 7 : weekday - 1
        return minute < endMinutes && weekdays.contains(previousWeekday)
    }

    static func activeEndDate(
        startMinutes: Int,
        endMinutes: Int,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        var end = calendar.date(byAdding: .minute, value: endMinutes, to: startOfDay) ?? date
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        if endMinutes < startMinutes, minute >= startMinutes {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        return end
    }
}
