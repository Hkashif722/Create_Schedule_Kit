import Testing
import Foundation
@testable import Create_Schedule_Kit

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
}

@Suite struct HolidayGenerationTests {

    @Test func generatesOneRowPerDayInRange() {
        // Jun 17 2026 (Wed) → Jun 23 2026 (Tue) = 7 days
        let rows = HolidayDay.generate(start: day(2026, 6, 17), end: day(2026, 6, 23))
        #expect(rows.count == 7)
    }

    @Test func weekendsAreNotAutoMarkedAsHolidays() {
        // Jun 17–23 2026 spans Sat Jun 20 and Sun Jun 21. Nothing is marked up front —
        // holidays are the user's own picks (Bug: weekends auto-marked by default).
        let rows = HolidayDay.generate(start: day(2026, 6, 17), end: day(2026, 6, 23))
        #expect(rows.contains { Calendar.current.component(.weekday, from: $0.date) == 7 })
        #expect(rows.contains { Calendar.current.component(.weekday, from: $0.date) == 1 })
        #expect(rows.allSatisfy { !$0.isHoliday })
    }

    @Test func everyGeneratedDayDefaultsToAWorkingDay() {
        let rows = HolidayDay.generate(start: day(2026, 6, 17), end: day(2026, 6, 23))
        #expect(rows.count == 7)
        #expect(rows.allSatisfy { !$0.isHoliday && $0.label == "Holiday" })
    }

    @Test func weekdaysDefaultToWorkingDaysLabelledHoliday() {
        let rows = HolidayDay.generate(start: day(2026, 6, 17), end: day(2026, 6, 19))
        #expect(rows.allSatisfy { !$0.isHoliday && $0.label == "Holiday" })
    }

    @Test func existingSelectionsArePreserved() {
        let start = day(2026, 6, 17)
        let end = day(2026, 6, 23)
        let base = HolidayDay.generate(start: start, end: end)
        // Mark a weekday (Jun 18) as a custom holiday.
        var existing = base
        if let idx = existing.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day(2026, 6, 18)) }) {
            existing[idx].isHoliday = true
            existing[idx].label = "Company Day"
        }

        let regenerated = HolidayDay.generate(start: start, end: end, existing: existing)
        let jun18 = regenerated.first { Calendar.current.isDate($0.date, inSameDayAs: day(2026, 6, 18)) }
        #expect(jun18?.isHoliday == true)
        #expect(jun18?.label == "Company Day")
    }

    @Test func startAndEndAreNeverHolidaysEvenOnWeekends() throws {
        // Jun 20 2026 (Sat) → Jun 27 2026 (Sat): both boundaries fall on a weekend.
        let rows = HolidayDay.generate(start: day(2026, 6, 20), end: day(2026, 6, 27))
        let first = try #require(rows.first)
        let last = try #require(rows.last)
        #expect(first.isHoliday == false)
        #expect(first.isLocked)
        #expect(last.isHoliday == false)
        #expect(last.isLocked)
        // The interior Sunday (Jun 21) is markable but not marked for the user.
        let jun21 = rows.first { Calendar.current.isDate($0.date, inSameDayAs: day(2026, 6, 21)) }
        #expect(jun21?.isHoliday == false)
        #expect(jun21?.isLocked == false)
    }

    @Test func existingMarkingOnBoundaryDayIsDropped() {
        let start = day(2026, 6, 17)
        let end = day(2026, 6, 23)
        // A row that marks the start day — as a hydrated API payload could.
        let existing = [
            HolidayDay(id: 0, date: start, isHoliday: true, label: "Founders Day"),
            HolidayDay(id: 6, date: end, isHoliday: true, label: "Closing Day")
        ]
        let rows = HolidayDay.generate(start: start, end: end, existing: existing)
        #expect(rows.first?.isHoliday == false)
        #expect(rows.last?.isHoliday == false)
        #expect(rows.filter { $0.isHoliday }.isEmpty) // nothing else was marked either
    }

    @Test func twoDayRangeHasNoMarkableDays() {
        let rows = HolidayDay.generate(start: day(2026, 6, 20), end: day(2026, 6, 21))
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.isLocked && !$0.isHoliday })
    }

    @Test func singleDayRangeProducesOneRow() {
        let single = day(2026, 6, 17)
        let rows = HolidayDay.generate(start: single, end: single)
        #expect(rows.count == 1)
        #expect(rows.first?.isLocked == true)
        #expect(rows.first?.isHoliday == false)
    }

    @Test func invertedRangeReturnsEmpty() {
        let rows = HolidayDay.generate(start: day(2026, 6, 23), end: day(2026, 6, 17))
        #expect(rows.isEmpty)
    }
}
