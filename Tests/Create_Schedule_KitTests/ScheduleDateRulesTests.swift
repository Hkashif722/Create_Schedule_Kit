import Testing
import Foundation
@testable import Create_Schedule_Kit

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
}

@Suite struct ScheduleDateRulesTests {

    @Test func startSelectionAutoPopulatesEndAndRegistration() {
        let start = date(2026, 8, 20)
        let result = ScheduleDateRules.autoPopulated(forStart: start)
        #expect(result.end == start)
        #expect(result.registrationEnd == start)
    }

    @Test func endMinimumEqualsStart() {
        let start = date(2026, 8, 20)
        #expect(ScheduleDateRules.endMinimum(forStart: start) == start)
    }

    @Test func endIsClampedNotBeforeStart() {
        let start = date(2026, 8, 20)
        let earlier = date(2026, 8, 18)
        let later = date(2026, 8, 25)
        #expect(ScheduleDateRules.clampedEnd(earlier, start: start) == start)
        #expect(ScheduleDateRules.clampedEnd(later, start: start) == later)
    }

    @Test func singleDayRangeIsNotMultiDay() {
        let start = date(2026, 8, 20)
        #expect(ScheduleDateRules.isMultiDay(start: start, end: start) == false)
    }

    @Test func sameCalendarDayWithDifferentTimesIsNotMultiDay() {
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date(2026, 8, 20))!
        let evening = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: date(2026, 8, 20))!
        #expect(ScheduleDateRules.isMultiDay(start: morning, end: evening) == false)
    }

    @Test func twoDayRangeIsMultiDay() {
        #expect(ScheduleDateRules.isMultiDay(start: date(2026, 8, 20), end: date(2026, 8, 21)))
    }

    @Test func missingDatesAreNotMultiDay() {
        let start = date(2026, 8, 20)
        #expect(ScheduleDateRules.isMultiDay(start: nil, end: start) == false)
        #expect(ScheduleDateRules.isMultiDay(start: start, end: nil) == false)
        #expect(ScheduleDateRules.isMultiDay(start: nil, end: nil) == false)
    }

    @Test func invertedRangeIsNotMultiDay() {
        #expect(ScheduleDateRules.isMultiDay(start: date(2026, 8, 25), end: date(2026, 8, 20)) == false)
    }

    // MARK: - Markable holidays (boundary days are locked working days)

    @Test func singleAndTwoDayRangesHaveNoMarkableHolidays() {
        let start = date(2026, 8, 20)
        #expect(ScheduleDateRules.hasMarkableHolidays(start: start, end: start) == false)
        #expect(ScheduleDateRules.hasMarkableHolidays(start: start, end: date(2026, 8, 21)) == false)
    }

    @Test func threeDayRangeHasOneMarkableDay() {
        #expect(ScheduleDateRules.hasMarkableHolidays(start: date(2026, 8, 20), end: date(2026, 8, 22)))
    }

    @Test func missingOrInvertedRangesHaveNoMarkableHolidays() {
        let start = date(2026, 8, 20)
        #expect(ScheduleDateRules.hasMarkableHolidays(start: nil, end: start) == false)
        #expect(ScheduleDateRules.hasMarkableHolidays(start: start, end: nil) == false)
        #expect(ScheduleDateRules.hasMarkableHolidays(start: nil, end: nil) == false)
        #expect(ScheduleDateRules.hasMarkableHolidays(start: date(2026, 8, 25), end: start) == false)
    }

    @Test func registrationWindowIsThreeDaysBeforeToStart() {
        let start = date(2026, 8, 20)
        let window = ScheduleDateRules.registrationWindow(forStart: start)
        #expect(window.max == start)
        #expect(window.min == date(2026, 8, 17))   // 20 Aug → 17 Aug
    }

    // MARK: - Time of day

    @Test func minutesSinceMidnightReadsTwelveHourPickerStrings() {
        #expect(ScheduleDateRules.minutesSinceMidnight(pickerTime(hour: 11, minute: 30)) == 11 * 60 + 30)
        #expect(ScheduleDateRules.minutesSinceMidnight(pickerTime(hour: 0, minute: 0)) == 0)
        #expect(ScheduleDateRules.minutesSinceMidnight(pickerTime(hour: 23, minute: 59)) == 23 * 60 + 59)
    }

    /// `ScheduleDraft.displayTime` passes API values through unchanged when it cannot
    /// convert them, so the 24-hour form has to parse too.
    @Test func minutesSinceMidnightAlsoReadsApiStyleTimes() {
        #expect(ScheduleDateRules.minutesSinceMidnight("16:47") == 16 * 60 + 47)
        #expect(ScheduleDateRules.minutesSinceMidnight("09:05") == 9 * 60 + 5)
    }

    @Test func minutesSinceMidnightRejectsGarbage() {
        #expect(ScheduleDateRules.minutesSinceMidnight("") == nil)
        #expect(ScheduleDateRules.minutesSinceMidnight("not a time") == nil)
    }

    /// The reported bug: 11:30 AM → 11:30 AM was accepted as a zero-length session.
    @Test func identicalStartAndEndTimeIsRefused() {
        let time = pickerTime(hour: 11, minute: 30)
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: time, end: time))
    }

    /// The second reported bug: 11:32 AM → 11:30 AM.
    @Test func endTimeEarlierThanStartIsRefused() {
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(
            start: pickerTime(hour: 11, minute: 32),
            end: pickerTime(hour: 11, minute: 30)
        ))
    }

    @Test func endTimeOneMinuteAfterStartIsAccepted() {
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(
            start: pickerTime(hour: 11, minute: 30),
            end: pickerTime(hour: 11, minute: 31)
        ) == false)
    }

    @Test func endTimeAcrossTheNoonBoundaryIsAccepted() {
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(
            start: pickerTime(hour: 9, minute: 0),
            end: pickerTime(hour: 17, minute: 30)
        ) == false)
    }

    @Test func aMissingTimeIsNotReportedAsOutOfOrder() {
        let time = pickerTime(hour: 11, minute: 30)
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: nil, end: time) == false)
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: time, end: nil) == false)
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: nil, end: nil) == false)
    }

    /// Fails open: an unparsable value must never be reported as invalid, or the wizard
    /// would wedge on a value the user cannot correct.
    @Test func unparsableTimesAreNotReportedAsOutOfOrder() {
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: "garbage", end: "also garbage") == false)
        #expect(ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: pickerTime(hour: 11, minute: 30), end: "garbage") == false)
    }
}

/// Reproduces what `TimePickerTextField` stores: a 12-hour `"h:mm a"` string in the
/// current locale. Built from a `Date` so the expectations hold on any machine.
private func pickerTime(hour: Int, minute: Int) -> String {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let value = Calendar.current.date(from: components)!
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: value)
}
