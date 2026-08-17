import Testing
import Foundation
@testable import Create_Schedule_Kit

private let calendar = Calendar.current

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d))!
}

private func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

private func endOfDay(_ date: Date) -> Date {
    calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        .addingTimeInterval(-1)
}

@Suite struct AttendanceDateRulesTests {

    // MARK: - Schedule range only

    @Test func boundsSpanTheScheduleRangeOnWholeDays() {
        let start = day(2026, 7, 6)
        let end = day(2026, 7, 10)
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: start,
            scheduleEnd: end,
            restrictToCurrentDate: false,
            today: day(2026, 8, 4)
        )
        #expect(bounds.min == startOfDay(start))
        #expect(bounds.max == endOfDay(end))
    }

    @Test func bothBoundaryDaysOfTheScheduleAreSelectable() {
        let start = day(2026, 7, 6)
        let end = day(2026, 7, 10)
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: start,
            scheduleEnd: end,
            restrictToCurrentDate: false,
            today: day(2026, 8, 4)
        )
        #expect(AttendanceDateRules.isSelectable(start, min: bounds.min, max: bounds.max))
        #expect(AttendanceDateRules.isSelectable(end, min: bounds.min, max: bounds.max))
        #expect(!AttendanceDateRules.isSelectable(day(2026, 7, 5), min: bounds.min, max: bounds.max))
        #expect(!AttendanceDateRules.isSelectable(day(2026, 7, 11), min: bounds.min, max: bounds.max))
    }

    @Test func singleDayScheduleLeavesThatDaySelectable() {
        let only = day(2026, 7, 2)
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: only,
            scheduleEnd: only,
            restrictToCurrentDate: false,
            today: day(2026, 8, 4)
        )
        // Regression: an instant-wide range left every day greyed out.
        #expect(bounds.min! < bounds.max!)
        #expect(AttendanceDateRules.isSelectable(only, min: bounds.min, max: bounds.max))
    }

    // MARK: - Intersection with the current-date restriction

    @Test func currentDateRestrictionNarrowsToTodayWhenInsideTheRange() {
        let today = day(2026, 7, 8)
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: day(2026, 7, 6),
            scheduleEnd: day(2026, 7, 10),
            restrictToCurrentDate: true,
            today: today
        )
        #expect(bounds.min == startOfDay(today))
        #expect(bounds.max == endOfDay(today))
        #expect(AttendanceDateRules.isSelectable(today, min: bounds.min, max: bounds.max))
        #expect(!AttendanceDateRules.isSelectable(day(2026, 7, 7), min: bounds.min, max: bounds.max))
        #expect(!AttendanceDateRules.isSelectable(day(2026, 7, 9), min: bounds.min, max: bounds.max))
    }

    @Test func nonOverlapYieldsAnEmptyRangeSoThePickerDisables() {
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: day(2026, 7, 6),
            scheduleEnd: day(2026, 7, 10),
            restrictToCurrentDate: true,
            today: day(2026, 8, 4)   // after the schedule ends
        )
        #expect(bounds.min! > bounds.max!)
    }

    // MARK: - Missing schedule dates (fetch failed / not yet arrived)

    @Test func noScheduleDatesAndNoRestrictionIsUnbounded() {
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: nil,
            scheduleEnd: nil,
            restrictToCurrentDate: false,
            today: day(2026, 8, 4)
        )
        #expect(bounds.min == nil)
        #expect(bounds.max == nil)
    }

    @Test func noScheduleDatesFallsBackToTodayOnlyWhenRestricted() {
        let today = day(2026, 8, 4)
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: nil,
            scheduleEnd: nil,
            restrictToCurrentDate: true,
            today: today
        )
        #expect(bounds.min == startOfDay(today))
        #expect(bounds.max == endOfDay(today))
    }

    @Test func aHalfKnownRangeBoundsOnlyThatSide() {
        let bounds = AttendanceDateRules.bounds(
            scheduleStart: day(2026, 7, 6),
            scheduleEnd: nil,
            restrictToCurrentDate: false,
            today: day(2026, 8, 4)
        )
        #expect(bounds.min == startOfDay(day(2026, 7, 6)))
        #expect(bounds.max == nil)
    }

    // MARK: - isSelectable

    @Test func isSelectableTreatsNilBoundsAsUnbounded() {
        let date = day(2026, 7, 8)
        #expect(AttendanceDateRules.isSelectable(date, min: nil, max: nil))
        #expect(AttendanceDateRules.isSelectable(date, min: nil, max: endOfDay(date)))
        #expect(AttendanceDateRules.isSelectable(date, min: startOfDay(date), max: nil))
        #expect(!AttendanceDateRules.isSelectable(date, min: startOfDay(day(2026, 7, 9)), max: nil))
        #expect(!AttendanceDateRules.isSelectable(date, min: nil, max: endOfDay(day(2026, 7, 7))))
    }
}
