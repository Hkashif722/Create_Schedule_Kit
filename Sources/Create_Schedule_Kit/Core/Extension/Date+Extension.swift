//
//  Date+Extension.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation

extension Date {

    /// Formats the date using the provided format string.
    func formatted(using format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

    /// `2026-08-06T00:00:00.000Z` — the picked calendar day, matching the payload the web
    /// client sends for `ILTSchedule/PostWithMeeting` and for the Nominate tab's attendance
    /// insert. NOT what the Attendance screen's Save sends — see `isoDayStartString`, which
    /// omits the `Z`; the trailing `Z` marks the value UTC and .NET shifts it to server-local
    /// time on parse, which stops it matching an already-marked row.
    ///
    /// The day is read in the device timezone and the time and `Z` are literals, so this
    /// names the day the user actually tapped rather than converting to UTC. That is
    /// deliberate — a real UTC conversion would shift the day for devices east/west of UTC.
    var isoDayStartUTCString: String {
        Self.isoDayStartUTCFormatter.string(from: self)
    }

    /// `2026-08-19T00:00:00` — the picked calendar day with no timezone marker, matching the
    /// payload the web client sends when saving attendance to `ILTTrainingAttendance`.
    ///
    /// Zone-less on purpose: the server reads it as an unspecified-kind `DateTime` and stores
    /// the day as sent. The time is a literal `00:00:00`, so a `selectedDate` carrying a
    /// wall-clock time still pins to the day start the server matches on.
    var isoDayStartString: String {
        Self.isoDayStartFormatter.string(from: self)
    }

    /// Cached alongside `isoDayStartUTCFormatter` — same per-user cost on save.
    private static let isoDayStartFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'00:00:00"
        return formatter
    }()

    /// Cached — the attendance insert formats one date per selected user, and building a
    /// `DateFormatter` per call is expensive.
    private static let isoDayStartUTCFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'00:00:00.000'Z'"
        return formatter
    }()
}
