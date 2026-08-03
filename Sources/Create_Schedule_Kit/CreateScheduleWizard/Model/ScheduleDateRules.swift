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

    /// Clamp a chosen end date so it is never before the start date.
    static func clampedEnd(_ selected: Date, start: Date) -> Date {
        max(selected, start)
    }

    /// Registration end date window: [start - leadDays, start].
    static func registrationWindow(forStart start: Date, calendar: Calendar = .current) -> (min: Date, max: Date) {
        let lower = calendar.date(byAdding: .day, value: -registrationLeadDays, to: start) ?? start
        return (min: lower, max: start)
    }
}
