//
//  ScheduleDateRules.swift
//  Create_Schedule_Kit
//
//  Pure, testable date rules for Step 1 (no UI / router dependencies).
//

import Foundation

enum ScheduleDateRules {

    /// Number of days before the start date that registration may close.
    static let registrationLeadDays = 3

    // MARK: - Non-working days

    /// Weekdays no schedule date may land on, in `Calendar` numbering — Sunday only.
    /// Handed to the date fields, which render these days dimmed and un-tappable.
    static let nonWorkingWeekdays: Set<Int> = [1] // 1 = Sunday

    /// Backstop for a Sunday that never came from a picker — a hydrated draft, or a
    /// calendar that somehow hands one back.
    static func isSunday(_ date: Date, calendar: Calendar = .current) -> Bool {
        nonWorkingWeekdays.contains(calendar.component(.weekday, from: date))
    }

    /// Selecting a start date auto-populates end and registration-end with the start date.
    static func autoPopulated(forStart start: Date) -> (end: Date, registrationEnd: Date) {
        (end: start, registrationEnd: start)
    }

    /// End date cannot be before the start date.
    static func endMinimum(forStart start: Date) -> Date { start }

    /// Holidays apply only when the schedule covers more than one calendar day.
    static func isMultiDay(start: Date?, end: Date?, calendar: Calendar = .current) -> Bool {
        guard let start, let end else { return false }
        return !calendar.isDate(start, inSameDayAs: end) && start < end
    }

    /// A holiday can only land strictly between the start and end dates — both boundary days
    /// are locked working days — so the range needs at least one interior day, i.e. three
    /// calendar days, before anything is markable. Fails closed on nil/inverted ranges.
    static func hasMarkableHolidays(start: Date?, end: Date?, calendar: Calendar = .current) -> Bool {
        guard let start, let end else { return false }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard let days = calendar.dateComponents([.day], from: startDay, to: endDay).day else { return false }
        return days >= 2
    }

    /// Clamp a chosen end date so it is never before the start date.
    static func clampedEnd(_ selected: Date, start: Date) -> Date {
        max(selected, start)
    }

    /// Registration end date window: [start - leadDays, start].
    static func registrationWindow(forStart start: Date, calendar: Calendar = .current) -> (min: Date, max: Date) {
        let lower = calendar.date(byAdding: .day, value: -registrationLeadDays, to: start) ?? start
        return (min: lower, max: start)
    }

    // MARK: - Time of day

    /// Canonical format used by the wizard, payloads, and schedule-status bucketing.
    static let timeFormat = "HH:mm"

    /// Seconds since midnight for an API or legacy picker time.
    ///
    /// New values are always stored as 24-hour `HH:mm`. The parser also accepts API
    /// values with seconds and the old locale-dependent 12-hour picker representation,
    /// so schedules created before the format change continue to edit and filter correctly.
    static func secondsSinceMidnight(_ raw: String, calendar: Calendar = .current) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2 || parts.count == 3,
           parts.allSatisfy({ !$0.isEmpty }),
           let hour = Int(parts[0]),
           let minute = Int(parts[1]),
           (0...23).contains(hour),
           (0...59).contains(minute) {
            let second: Int
            if parts.count == 3 {
                guard let parsedSecond = Int(parts[2]), (0...59).contains(parsedSecond) else { return nil }
                second = parsedSecond
            } else {
                second = 0
            }
            return hour * 3_600 + minute * 60 + second
        }

        // Compatibility with drafts persisted by the former `h:mm a` picker.
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return nil }
        let dateParts = calendar.dateComponents([.hour, .minute, .second], from: date)
        guard let hour = dateParts.hour, let minute = dateParts.minute else { return nil }
        return hour * 3_600 + minute * 60 + (dateParts.second ?? 0)
    }

    /// Minutes since midnight for a stored time string.
    ///
    /// The draft stores 24-hour `HH:mm` values. API `HH:mm:ss` values and legacy
    /// 12-hour picker values are accepted for backward compatibility.
    static func minutesSinceMidnight(_ raw: String, calendar: Calendar = .current) -> Int? {
        secondsSinceMidnight(raw, calendar: calendar).map { $0 / 60 }
    }

    /// Normalizes supported time representations to the 24-hour value expected by the API.
    static func canonical24HourTime(_ raw: String, calendar: Calendar = .current) -> String? {
        guard let seconds = secondsSinceMidnight(raw, calendar: calendar) else { return nil }
        return String(format: "%02d:%02d", seconds / 3_600, (seconds % 3_600) / 60)
    }

    /// Merges a calendar day with a parsed time of day.
    static func moment(
        on date: Date,
        time raw: String,
        calendar: Calendar = .current
    ) -> Date? {
        guard let seconds = secondsSinceMidnight(raw, calendar: calendar) else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .second, value: seconds, to: dayStart)
    }

    /// True when the pair is provably out of order — both times parse and the end is not
    /// strictly later than the start. Equal times count as invalid: a schedule that ends
    /// the minute it begins is a zero-length session.
    ///
    /// Deliberately fails *open*: a time that cannot be parsed is not reported as invalid,
    /// so an unexpected locale or format can never wedge the wizard on a value the user
    /// has no way to correct.
    static func isEndTimeBeforeOrEqualToStart(start: String?, end: String?, calendar: Calendar = .current) -> Bool {
        guard let start, let end,
              let startMinutes = minutesSinceMidnight(start, calendar: calendar),
              let endMinutes = minutesSinceMidnight(end, calendar: calendar)
        else { return false }
        return endMinutes <= startMinutes
    }

    // MARK: - Past-dated schedules

    /// The picked day carrying the parsed `startTime` — any time component on `startDate` is discarded.
    static func startMoment(
        startDate: Date,
        startTime: String?,
        calendar: Calendar = .current
    ) -> Date {
        guard let raw = startTime,
              let moment = moment(on: startDate, time: raw, calendar: calendar)
        else { return calendar.startOfDay(for: startDate) }
        return moment
    }

    /// Gate for the post-create nomination prompt — only the start matters, so an already-running multi-day schedule counts as past.
    static func isStartInPast(
        startDate: Date?,
        startTime: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let startDate else { return false }
        guard let raw = startTime, minutesSinceMidnight(raw, calendar: calendar) != nil else {
            return calendar.startOfDay(for: startDate) < calendar.startOfDay(for: now)
        }
        return startMoment(startDate: startDate, startTime: raw, calendar: calendar) < now
    }
}
