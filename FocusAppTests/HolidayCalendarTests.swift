import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class HolidayCalendarTests: XCTestCase {
    private func day(_ title: String, _ year: Int) -> String? {
        HolidayCalendar.events(in: year).first { $0.title == title }?.day
    }
    func testRequestedAnnualEventsAndChangingEasterDates() {
        for year in 2026...2035 {
            XCTAssertEqual(day("Valentine’s Day", year), "\(year)-02-14")
            XCTAssertEqual(day("Halloween", year), "\(year)-10-31")
            XCTAssertEqual(day("Christmas", year), "\(year)-12-25")
        }
        XCTAssertEqual(day("Easter", 2026), "2026-04-05")
        XCTAssertEqual(day("Easter", 2027), "2027-03-28")
        XCTAssertEqual(day("Easter", 2028), "2028-04-16")
        XCTAssertEqual(day("Good Friday", 2027), "2027-03-26")
        XCTAssertEqual(day("Lunar New Year", 2026), "2026-02-17")
        XCTAssertEqual(day("Lunar New Year", 2027), "2027-02-06")
        XCTAssertEqual(day("Mother’s Day (many countries)", 2027), "2027-05-09")
        XCTAssertEqual(day("Thanksgiving (US)", 2026), "2026-11-26")
    }
    func testOfficialJapaneseHolidayListsIncludeSubstitutesAndCitizensDays() {
        let dates2026 = Set(HolidayCalendar.events(in: 2026).filter(\.japanesePublicHoliday).map(\.day))
        let expected = ["01-01", "01-12", "02-11", "02-23", "03-20", "04-29", "05-03", "05-04", "05-05", "05-06", "07-20", "08-11", "09-21", "09-22", "09-23", "10-12", "11-03", "11-23"]
        XCTAssertEqual(dates2026, Set(expected.map { "2026-" + $0 }))
        let dates2027 = Set(HolidayCalendar.events(in: 2027).filter(\.japanesePublicHoliday).map(\.day))
        XCTAssertEqual(dates2027.count, 17)
        XCTAssertTrue(dates2027.contains("2027-03-22"))
        XCTAssertEqual(day("Coming of Age Day (Japan)", 2027), "2027-01-11")
        XCTAssertFalse(HolidayCalendar.events(in: 2027).contains(where: \.projected))
        // Official data handles Olympic exceptions rather than applying current rules backwards.
        XCTAssertEqual(day("Marine Day (Japan)", 2021), "2021-07-22")
    }
    func testFutureRulesAndEquinoxesAreExplicitlyProjected() {
        XCTAssertEqual(day("Vernal Equinox Day (Japan)", 2028), "2028-03-20")
        XCTAssertEqual(day("Autumnal Equinox Day (Japan)", 2028), "2028-09-22")
        XCTAssertEqual(day("Substitute Holiday (Japan)", 2029), "2029-02-12")
        XCTAssertEqual(day("Vernal Equinox Day (Japan)", 2050), "2050-03-20")
        XCTAssertTrue(HolidayCalendar.events(in: 2028).filter(\.japanesePublicHoliday).allSatisfy(\.projected))
    }
    func testCivilDateLookupWithJapaneseDisplayCalendarAndDifferentTimeZones() throws {
        for zone in ["Asia/Tokyo", "America/Los_Angeles", "Pacific/Auckland"] {
            var display = Calendar(identifier: .japanese)
            display.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            var gregorian = Calendar(identifier: .gregorian)
            gregorian.timeZone = display.timeZone
            let date = try XCTUnwrap(gregorian.date(from: DateComponents(year: 2027, month: 12, day: 25, hour: 12)))
            XCTAssertTrue(HolidayCalendar.events(on: date, calendar: display).contains { $0.title == "Christmas" && $0.day == "2027-12-25" })
        }
    }
    func testOverlayHasStableIDsAndDoesNotMutateSavedEvents() {
        let first = HolidayCalendar.events(in: 2026)
        XCTAssertEqual(first, HolidayCalendar.events(in: 2026))
        XCTAssertEqual(Set(first.map(\.id)).count, first.count)
        XCTAssertEqual(LifeState().events, [])
    }
}
