//
//  AttendanceDateRules.swift
//  Create_Schedule_Kit
//
//  Pure, testable bounds for the "Attendance for the Date" calendar (no UI / router
//  dependencies). Two independent rules constrain the picker and are intersected:
//
//   • the schedule's own [startDate, endDate] range (ILTSchedule/GetScheduleDetailsByID)
//   • the `AttendanceOnCurrentDate` config flag, which narrows selection to today
//

import Foundation

enum AttendanceDateRules {

    /// Selectable bounds for the attendance date picker.
    ///
    /// Bounds are whole-day: the lower bound is the start of its day and the upper bound the
    /// end of its day, so both boundary days are actually selectable in the graphical
    /// `DatePicker` (an instant-wide range leaves every day greyed out).
    ///
    /// - Returns `(nil, nil)` when neither rule applies — the calendar stays unbounded.
    /// - Returns `min > max` when the schedule range and the current-date restriction don't
    ///   overlap. That is deliberate: the shared calendar modal reads an empty range as
    ///   "nothing selectable" and disables itself.
    static func bounds(
        scheduleStart: Date?,
        scheduleEnd: Date?,
        restrictToCurrentDate: Bool,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> (min: Date?, max: Date?) {

        var lowerBounds: [Date] = []
        var upperBounds: [Date] = []

        if let scheduleStart { lowerBounds.append(startOfDay(scheduleStart, calendar)) }
        if let scheduleEnd { upperBounds.append(endOfDay(scheduleEnd, calendar)) }

        if restrictToCurrentDate {
            lowerBounds.append(startOfDay(today, calendar))
            upperBounds.append(endOfDay(today, calendar))
        }

        // Intersection: the latest lower bound and the earliest upper bound. No clamping —
        // a non-overlap must survive as min > max for the picker to disable itself.
        return (min: lowerBounds.max(), max: upperBounds.min())
    }

    /// Whether `date` falls inside the given bounds. A `nil` bound is unbounded on that side.
    static func isSelectable(_ date: Date, min: Date?, max: Date?) -> Bool {
        if let min, date < min { return false }
        if let max, date > max { return false }
        return true
    }

    // MARK: - Day boundaries

    private static func startOfDay(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    /// One second before midnight of the following day, so the whole day is inside the range.
    private static func endOfDay(_ date: Date, _ calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else { return start }
        return nextDay.addingTimeInterval(-1)
    }
}
