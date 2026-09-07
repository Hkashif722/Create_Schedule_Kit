import Testing
import Foundation
@testable import Create_Schedule_Kit

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
}

@Suite struct ScheduleDateRulesTests {

    // MARK: - Sunday is not a working day (Bug 78418)

    @Test func sundayIsNotSelectable() {
        // 2026-08-23 is a Sunday.
        #expect(ScheduleDateRules.isSunday(date(2026, 8, 23)))
    }

    @Test func onlySundayIsExcludedFromThePickers() {
        // The value handed to the date fields, which dim these weekdays in the calendar.
        #expect(ScheduleDateRules.nonWorkingWeekdays == [1])
    }

    @Test func everyOtherWeekdayIsSelectable() {
        // Monday 2026-08-24 through Saturday 2026-08-29.
        for day in 24...29 {
            #expect(ScheduleDateRules.isSunday(date(2026, 8, day)) == false)
        }
    }

    @Test func timeOfDayDoesNotAffectTheSundayRule() {
        let sunday = date(2026, 8, 23)
        let lateSunday = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: sunday)!
        let earlySunday = Calendar.current.date(bySettingHour: 0, minute: 1, second: 0, of: sunday)!
        #expect(ScheduleDateRules.isSunday(lateSunday))
        #expect(ScheduleDateRules.isSunday(earlySunday))
    }

    @Test func autoPopulatedDatesInheritANonSundayStart() {
        // End and registration-end copy the start date, so a refused Sunday can never
        // reach them through auto-populate.
        let monday = date(2026, 8, 24)
        let populated = ScheduleDateRules.autoPopulated(forStart: monday)
        #expect(ScheduleDateRules.isSunday(populated.end) == false)
        #expect(ScheduleDateRules.isSunday(populated.registrationEnd) == false)
    }

    @Test func clampingAnEarlyEndDateFallsBackToTheNonSundayStart() {
        let monday = date(2026, 8, 24)
        let clamped = ScheduleDateRules.clampedEnd(date(2026, 8, 20), start: monday)
        #expect(clamped == monday)
        #expect(ScheduleDateRules.isSunday(clamped) == false)
    }

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

    @Test func minutesSinceMidnightReadsCanonical24HourTimes() {
        #expect(ScheduleDateRules.minutesSinceMidnight("11:30") == 11 * 60 + 30)
        #expect(ScheduleDateRules.minutesSinceMidnight("00:00") == 0)
        #expect(ScheduleDateRules.minutesSinceMidnight("23:59") == 23 * 60 + 59)
    }

    @Test func apiTimesWithSecondsAreParsedExactly() {
        #expect(ScheduleDateRules.secondsSinceMidnight("16:47:31") == 16 * 3_600 + 47 * 60 + 31)
    }

    @Test func oldTwelveHourPickerValuesRemainCompatible() {
        #expect(ScheduleDateRules.minutesSinceMidnight(pickerTime(hour: 0, minute: 5)) == 5)
        #expect(ScheduleDateRules.minutesSinceMidnight(pickerTime(hour: 16, minute: 47)) == 16 * 60 + 47)
    }

    @Test func canonicalTimeAlwaysUses24HourFormat() {
        #expect(ScheduleDateRules.canonical24HourTime("9:05") == "09:05")
        #expect(ScheduleDateRules.canonical24HourTime("19:10:45") == "19:10")
        #expect(ScheduleDateRules.canonical24HourTime(pickerTime(hour: 16, minute: 47)) == "16:47")
    }

    @Test func minutesSinceMidnightRejectsGarbage() {
        #expect(ScheduleDateRules.minutesSinceMidnight("") == nil)
        #expect(ScheduleDateRules.minutesSinceMidnight("not a time") == nil)
        #expect(ScheduleDateRules.minutesSinceMidnight("24:00") == nil)
        #expect(ScheduleDateRules.minutesSinceMidnight("12:60") == nil)
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

    // MARK: - Past-dated schedules (nomination-prompt gate)

    @Test func startMomentCarriesThePickedTimeOntoThePickedDay() {
        let day = date(2026, 8, 20)
        let moment = ScheduleDateRules.startMoment(startDate: day, startTime: pickerTime(hour: 14, minute: 45))
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: moment)
        #expect(parts.year == 2026)
        #expect(parts.month == 8)
        #expect(parts.day == 20)
        #expect(parts.hour == 14)
        #expect(parts.minute == 45)
    }

    @Test func startMomentIgnoresTheTimeComponentOfTheDate() {
        let dayWithTime = Calendar.current.date(bySettingHour: 23, minute: 15, second: 0, of: date(2026, 8, 20))!
        let moment = ScheduleDateRules.startMoment(startDate: dayWithTime, startTime: pickerTime(hour: 9, minute: 0))
        let parts = Calendar.current.dateComponents([.day, .hour, .minute], from: moment)
        #expect(parts.day == 20)
        #expect(parts.hour == 9)
        #expect(parts.minute == 0)
    }

    @Test func aStartOnAnEarlierDayIsInThePast() {
        let now = at(2026, 8, 20, hour: 12, minute: 0)
        #expect(ScheduleDateRules.isStartInPast(
            startDate: date(2026, 8, 19),
            startTime: pickerTime(hour: 9, minute: 0),
            now: now
        ) == true)
    }

    @Test func aStartOnALaterDayIsNotInThePast() {
        let now = at(2026, 8, 20, hour: 12, minute: 0)
        #expect(ScheduleDateRules.isStartInPast(
            startDate: date(2026, 8, 21),
            startTime: pickerTime(hour: 9, minute: 0),
            now: now
        ) == false)
    }

    @Test func anEarlierTimeTodayIsInThePast() {
        let now = at(2026, 8, 20, hour: 12, minute: 0)
        #expect(ScheduleDateRules.isStartInPast(
            startDate: date(2026, 8, 20),
            startTime: pickerTime(hour: 9, minute: 30),
            now: now
        ) == true)
    }

    @Test func aLaterTimeTodayIsNotInThePast() {
        let now = at(2026, 8, 20, hour: 12, minute: 0)
        #expect(ScheduleDateRules.isStartInPast(
            startDate: date(2026, 8, 20),
            startTime: pickerTime(hour: 15, minute: 30),
            now: now
        ) == false)
    }

    @Test func aStartedMultiDayScheduleIsInThePast() {
        let now = at(2026, 8, 20, hour: 12, minute: 0)
        #expect(ScheduleDateRules.isStartInPast(
            startDate: date(2026, 8, 18),
            startTime: pickerTime(hour: 9, minute: 0),
            now: now
        ) == true)
    }

    @Test func aMissingStartDateIsNotInThePast() {
        #expect(ScheduleDateRules.isStartInPast(
            startDate: nil,
            startTime: pickerTime(hour: 9, minute: 0),
            now: at(2026, 8, 20, hour: 12, minute: 0)
        ) == false)
    }

    @Test func anUnparsableTimeFallsBackToAWholeDayComparison() {
        let now = at(2026, 8, 20, hour: 12, minute: 0)
        #expect(ScheduleDateRules.isStartInPast(startDate: date(2026, 8, 20), startTime: "garbage", now: now) == false)
        #expect(ScheduleDateRules.isStartInPast(startDate: date(2026, 8, 20), startTime: nil, now: now) == false)
        #expect(ScheduleDateRules.isStartInPast(startDate: date(2026, 8, 19), startTime: nil, now: now) == true)
    }
}

private func at(_ y: Int, _ m: Int, _ d: Int, hour: Int, minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
}

/// Reproduces values stored by the former 12-hour picker for compatibility coverage.
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
