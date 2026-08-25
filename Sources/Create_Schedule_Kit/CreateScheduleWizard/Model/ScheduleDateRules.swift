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

    /// Minutes since midnight for a stored time string.
    ///
    /// The draft keeps times as 12-hour `"h:mm a"` strings in `Locale.current` — exactly
    /// what `TimePickerTextField` emits — so that is tried first. `"HH:mm"` is the
    /// fallback because `ScheduleDraft.displayTime` passes unconvertible API values
    /// through unchanged. `nil` when neither format parses.
    static func minutesSinceMidnight(_ raw: String, calendar: Calendar = .current) -> Int? {
        let candidates: [(format: String, locale: Locale)] = [
            ("h:mm a", .current),
            ("HH:mm", Locale(identifier: "en_US_POSIX"))
        ]
        for candidate in candidates {
            let formatter = DateFormatter()
            formatter.locale = candidate.locale
            formatter.dateFormat = candidate.format
            guard let date = formatter.date(from: raw) else { continue }
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            guard let hour = parts.hour, let minute = parts.minute else { continue }
            return hour * 60 + minute
        }
        return nil
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
}
