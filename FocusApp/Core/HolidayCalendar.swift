import Foundation

struct CalendarObservance: Identifiable, Equatable {
    let day: String // Gregorian civil date, independent of display calendar/time zone.
    let title: String
    let japanesePublicHoliday: Bool
    var projected = false
    var id: String { day + "|" + title }
}

// Offline overlay. Never inserts, edits, migrates or deletes the user's events.
enum HolidayCalendar {
    static func events(in year: Int) -> [CalendarObservance] {
        guard (1583...9999).contains(year) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        func key(_ date: Date) -> String { TimePolicy.dayKey(date, calendar: calendar) }
        var result: [CalendarObservance] = []
        func add(_ title: String, _ month: Int, _ day: Int) {
            result.append(CalendarObservance(day: key(date(month, day)), title: title, japanesePublicHoliday: false))
        }
        func weekday(_ month: Int, _ weekday: Int, _ ordinal: Int) -> Int {
            let first = calendar.component(.weekday, from: date(month, 1))
            return 1 + (weekday - first + 7) % 7 + (ordinal - 1) * 7
        }
        let fixed: [(String, Int, Int)] = [
            ("New Year’s Day", 1, 1), ("Valentine’s Day", 2, 14),
            ("Hinamatsuri", 3, 3), ("International Women’s Day", 3, 8),
            ("White Day", 3, 14), ("World Water Day", 3, 22),
            ("April Fools’ Day", 4, 1), ("Earth Day", 4, 22),
            ("World Environment Day", 6, 5), ("Tanabata", 7, 7),
            ("International Day of Peace", 9, 21), ("Halloween", 10, 31),
            ("Human Rights Day", 12, 10), ("Christmas Eve", 12, 24),
            ("Christmas", 12, 25), ("New Year’s Eve", 12, 31)
        ]
        for (title, month, day) in fixed { add(title, month, day) }
        add("Mother’s Day (many countries)", 5, weekday(5, 1, 2))
        add("Father’s Day (many countries)", 6, weekday(6, 1, 3))
        add("Thanksgiving (US)", 11, weekday(11, 5, 4))

        // Gregorian computus: annual date, not a fixed April entry.
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let easter = date((h + l - 7 * m + 114) / 31, (h + l - 7 * m + 114) % 31 + 1)
        for (title, offset) in [("Good Friday", -2), ("Easter", 0), ("Easter Monday", 1)] {
            let day = calendar.date(byAdding: .day, value: offset, to: easter)!
            result.append(CalendarObservance(day: key(day), title: title, japanesePublicHoliday: false))
        }

        // Foundation supplies lunisolar calendar conversion, not a hard-coded date.
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = calendar.timeZone
        for offset in 0..<40 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(1, 15))!
            let parts = chinese.dateComponents(in: chinese.timeZone, from: day)
            if parts.month == 1 && parts.day == 1 && parts.isLeapMonth != true {
                result.append(CalendarObservance(day: key(day), title: "Lunar New Year", japanesePublicHoliday: false))
                break
            }
        }

        if year <= JapaneseHolidayData.lastConfirmedYear {
            let prefix = "\(year)-"
            for (day, title) in JapaneseHolidayData.confirmed where day.hasPrefix(prefix) {
                result.append(CalendarObservance(day: day, title: title + " (Japan)", japanesePublicHoliday: true))
            }
        } else if year <= 2099 {
            // Future dates follow current law. Equinoxes are projections, not
            // official declarations; the UI explicitly labels this distinction.
            var holidays: [Date: String] = [:]
            func jp(_ title: String, _ month: Int, _ day: Int) { holidays[date(month, day)] = title }
            jp("New Year’s Day", 1, 1)
            jp("Coming of Age Day", 1, weekday(1, 2, 2))
            jp("National Foundation Day", 2, 11)
            jp("Emperor’s Birthday", 2, 23)
            let spring = Int(floor(20.8431 + 0.242194 * Double(year - 1980) - Double((year - 1980) / 4)))
            let autumn = Int(floor(23.2488 + 0.242194 * Double(year - 1980) - Double((year - 1980) / 4)))
            jp("Vernal Equinox Day", 3, spring)
            jp("Showa Day", 4, 29)
            jp("Constitution Memorial Day", 5, 3)
            jp("Greenery Day", 5, 4)
            jp("Children’s Day", 5, 5)
            jp("Marine Day", 7, weekday(7, 2, 3))
            jp("Mountain Day", 8, 11)
            jp("Respect for the Aged Day", 9, weekday(9, 2, 3))
            jp("Autumnal Equinox Day", 9, autumn)
            jp("Sports Day", 10, weekday(10, 2, 2))
            jp("Culture Day", 11, 3)
            jp("Labor Thanksgiving Day", 11, 23)
            let national = holidays
            // A non-Sunday between two national holidays is a Citizen's Holiday.
            for day in national.keys {
                let next = calendar.date(byAdding: .day, value: 1, to: day)!
                let after = calendar.date(byAdding: .day, value: 2, to: day)!
                if national[next] == nil && national[after] != nil && calendar.component(.weekday, from: next) != 1 {
                    holidays[next] = "Citizen’s Holiday"
                }
            }
            // Sunday holidays move to the next non-holiday, including Golden Week.
            for day in national.keys.sorted() where calendar.component(.weekday, from: day) == 1 {
                var next = calendar.date(byAdding: .day, value: 1, to: day)!
                while holidays[next] != nil { next = calendar.date(byAdding: .day, value: 1, to: next)! }
                holidays[next] = "Substitute Holiday"
            }
            for (day, title) in holidays {
                result.append(CalendarObservance(day: key(day), title: title + " (Japan)", japanesePublicHoliday: true, projected: true))
            }
        }
        return result.sorted { ($0.day, $0.title) < ($1.day, $1.title) }
    }

    static func events(on date: Date, calendar: Calendar = .current) -> [CalendarObservance] {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let day = TimePolicy.dayKey(date, calendar: gregorian)
        return events(in: gregorian.component(.year, from: date)).filter { $0.day == day }
    }
}
