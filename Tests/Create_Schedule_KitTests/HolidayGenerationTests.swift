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

    @Test func weekendsDefaultToHolidaysLabelledWeekend() {
        let rows = HolidayDay.generate(start: day(2026, 6, 17), end: day(2026, 6, 23))
        let marked = rows.filter { $0.isHoliday }
        // Jun 20 (Sat) + Jun 21 (Sun)
        #expect(marked.count == 2)
        #expect(marked.allSatisfy { $0.label == "Weekend" })
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

    @Test func invertedRangeReturnsEmpty() {
        let rows = HolidayDay.generate(start: day(2026, 6, 23), end: day(2026, 6, 17))
        #expect(rows.isEmpty)
    }
}
