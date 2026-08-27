//
//  SchedulePermissions.swift
//  Create_Schedule_Kit
//
//  What the logged-in user is allowed to do inside this package, derived from the role code
//  the host supplies via `CreateScheduleKitConfig.userRole`.
//
//  Today there is one restricted role: "ET" — an external trainer. An ET is a participant in
//  the delivery, not an owner of the schedule, so they may view a schedule and mark its
//  attendance, and nothing else. Every other role keeps the full set.
//
//  A pure value type rather than a lookup on the API manager so the rules are testable
//  without configuring the package. `BaseViewModel.permissions` is the read path for screens.
//

import Foundation

struct SchedulePermissions: Equatable {

    /// The host's role code, compared case-insensitively.
    let userRole: String

    /// External trainer.
    static let externalTrainerRole = "ET"

    /// Reads the role configured by the host. An unconfigured package reports an empty role,
    /// which is unrestricted — the package is only ever unconfigured in previews and tests.
    static var current: SchedulePermissions {
        SchedulePermissions(userRole: CreateScheduleKitAPIManager.shared.getUserRole)
    }
}

// MARK: - Roles

extension SchedulePermissions {

    var isExternalTrainer: Bool {
        userRole.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(Self.externalTrainerRole) == .orderedSame
    }
}

// MARK: - Capabilities

extension SchedulePermissions {

    /// Creating a schedule from the list's "+ New" button.
    var canCreateSchedule: Bool { !isExternalTrainer }

    /// Opening the wizard in edit mode from a card's pencil.
    var canEditSchedule: Bool { !isExternalTrainer }

    /// Opening the Cancel Schedule sheet from a card.
    var canCancelSchedule: Bool { !isExternalTrainer }

    /// Every entry point into nomination: the post-create prompt, "+ Add Nominee" on the
    /// details screen, deleting a nominee, and the Nominate tab on Update Attendance.
    var canNominate: Bool { !isExternalTrainer }

    /// Always allowed — marking attendance is the external trainer's job.
    var canMarkAttendance: Bool { true }

    /// Always allowed.
    var canViewSchedule: Bool { true }
}
