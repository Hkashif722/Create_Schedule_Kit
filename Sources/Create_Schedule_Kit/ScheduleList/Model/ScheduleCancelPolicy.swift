//
//  ScheduleCancelPolicy.swift
//  Create_Schedule_Kit
//
//  Pure, testable rules for whether a schedule may be cancelled (no UI / router
//  dependencies). The Cancel icon stays on the card either way, so a refusal is explained
//  with a toast rather than by silently hiding the action.
//
//  `Enable_PastScheduleCancel` (attribute: "Allow to cancel past schedules for an ILT
//  Course?") is what an org sets to cancel schedules whose time has passed.
//

import Foundation

enum ScheduleCancelPolicy {

    /// Why a cancellation was refused. `nil` from `refusal(for:...)` means go ahead.
    enum Refusal: Equatable {
        /// Already cancelled — nothing left to cancel, whatever the org allows.
        case alreadyCancelled
        /// Running right now.
        case inProgress
        /// Finished.
        case over
        /// The registration window closed before today.
        case registrationClosed

        var message: String {
            switch self {
            case .alreadyCancelled:   return "This schedule is already cancelled."
            case .inProgress:         return "Training cannot be cancelled as training already started."
            case .over:               return "Schedule is over."
            case .registrationClosed: return "Training cannot be canceled, as training already started."
            }
        }

        /// A schedule that is already cancelled is a statement of fact, not an error.
        var isInformational: Bool { self == .alreadyCancelled }

        /// Whether `Enable_PastScheduleCancel` can lift this refusal.
        var isLiftedByPastScheduleCancel: Bool {
            switch self {
            case .over, .registrationClosed:  return true
            case .alreadyCancelled, .inProgress: return false
            }
        }
    }

    /// The reason this schedule cannot be cancelled, or `nil` when it can.
    ///
    /// The schedule's own start/end moments are checked separately from the registration
    /// window because the two come apart on short schedules: a same-day training whose
    /// registration end date is today is still "within the window" while it runs and after
    /// it finishes, which is how a completed schedule once reached the cancel sheet.
    ///
    /// With `allowsPastCancel` on, a finished schedule and a closed registration window
    /// both stop being refusals. A training that is *running* is not a past schedule —
    /// those attendees are in the room — so that refusal stands either way, as does a
    /// schedule that is already cancelled.
    static func refusal(
        for schedule: ScheduleListDataModel.Schedule,
        allowsPastCancel: Bool,
        now: Date = Date()
    ) -> Refusal? {
        if schedule.isCancelled { return .alreadyCancelled }

        if schedule.hasStarted(now: now), !schedule.hasEnded(now: now) { return .inProgress }

        if schedule.hasEnded(now: now) {
            return allowsPastCancel ? nil : .over
        }

        if !schedule.isWithinRegistrationWindow {
            return allowsPastCancel ? nil : .registrationClosed
        }

        return nil
    }
}
