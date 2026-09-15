//
//  NavigationViewModel.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation
import SwiftUIUtilities

// All module navigation models are nested here as an extension on `NavigationViewModel`
// (a struct provided by SwiftUIUtilities). Add `XxxNavModel` types as feature modules are built.
extension NavigationViewModel {

    // MARK: - Holidays bottom sheet
    struct HolidaysSheetNavModel {
        let startDate: Date
        let endDate: Date
        let existing: [HolidayDay]
        let onSave: ([HolidayDay]) -> Void
    }

    // MARK: - Feedback module picker bottom sheet
    // Single-select: a schedule has at most one feedback module. Module list is fetched by the
    // picker's own view model (paginated, server-side search).
    struct FeedbackPickerNavModel {
        let selected: ScheduleFeedbackDataModel.FeedbackModule?
        let onSave: (ScheduleFeedbackDataModel.FeedbackModule) -> Void
    }

    // MARK: - Create new trainer bottom sheet
    // Opened from Step 2's Trainer field when Trainer Type is External. `onCreated` hands the
    // freshly created account back as a `Trainer` so Step 2 can select it immediately — the
    // sheet is torn down at dismissal, so Step 2 also owns the success toast.
    struct CreateTrainerNavModel {
        let onCreated: (ScheduleLogisticsDataModel.Trainer) -> Void
    }

    // MARK: - Schedule details
    struct ScheduleDetailNavModel {
        let schedule: ScheduleListDataModel.Schedule
    }

    // MARK: - Waiting list / availability
    // Pushed from the Schedule Details header chips. `mode` picks which list the screen
    // shows; the identifiers are the ones both list bodies need.
    struct ScheduleUsersNavModel {
        let mode: ScheduleUsersDataModel.Mode
        let scheduleID: Int
        let courseID: Int
        let moduleID: Int
    }

    // MARK: - Update attendance
    // Pushed from a schedule card's Attendance action. Carries the schedule's identifiers
    // plus display strings for the read-only info card.
    struct AttendanceNavModel {
        let scheduleID: Int
        let courseID: Int
        let moduleID: Int
        let courseName: String
        let moduleName: String
        let scheduleCode: String
        let dateRangeText: String
    }

    // MARK: - Bulk mark / attendees
    // Both are pushed from Update Attendance and share one view model; `mode` picks which
    // screen renders. `attendanceDate` is the day picked on Update Attendance — optional
    // because the view model must not trust the caller, and Attendees needs no date at all.
    struct AttendanceUsersNavModel {
        let mode: AttendanceUsersMode
        let scheduleID: Int
        let courseID: Int
        let moduleID: Int
        let scheduleCode: String
        let attendanceDate: Date?
        /// Fired after a successful save or delete so the screen behind refreshes its count.
        let onAttendanceChanged: () -> Void
    }

    // MARK: - QR attendance
    // Pushed from Update Attendance's Scan QR. A scan always marks Attended, so no status
    // travels — only the day and the schedule's identifiers.
    struct AttendanceQRScannerNavModel {
        let scheduleID: Int
        let courseID: Int
        let moduleID: Int
        /// Sent as `CourseTitle` on the mark body.
        let courseName: String
        let attendanceDate: Date
        /// Fired after a learner is successfully marked, so the screen behind refreshes.
        let onMarked: () -> Void
    }

    // Presented from Update Attendance's Download. The QR is generated on the device — no
    // endpoint produces it.
    struct ScheduleQRCodeNavModel {
        let scheduleID: Int
        let courseID: Int
        let moduleID: Int
        let courseName: String
        let scheduleCode: String
        let attendanceDate: Date
    }

    // MARK: - Cancel schedule bottom sheet
    // Opened from a schedule card's Cancel Schedule action. `onCancelled` fires after a successful
    // cancellation so the list — which is still on screen — owns the success toast and the reload;
    // the sheet's own view model is torn down at dismissal and its toast overlay with it.
    struct CancelScheduleNavModel {
        let scheduleID: Int
        let scheduleCode: String
        let moduleName: String
        let onCancelled: () -> Void
    }

    // MARK: - Nominate users bottom sheet
    // Presented after a schedule is created (if the creator opts to nominate). Carries the
    // just-created schedule's identifiers; `onComplete` finishes the wizard afterwards.
    struct NominateUsersNavModel {
        let scheduleCode: String
        let courseID: Int
        let moduleID: Int
        let scheduleID: Int?
        let onComplete: () -> Void
        /// Supplied only when Nominate is embedded in the Update Attendance screen. Its
        /// presence switches the submit from the nomination API to a direct attendance
        /// insert — a back-dated schedule cannot be nominated for. A closure rather than a
        /// snapshot so the date/status read stays live across the tab's teardown/recreate.
        let attendanceContext: (() -> NominateAttendanceContext)?

        init(scheduleCode: String,
             courseID: Int,
             moduleID: Int,
             scheduleID: Int? = nil,
             onComplete: @escaping () -> Void,
             attendanceContext: (() -> NominateAttendanceContext)? = nil) {
            self.scheduleCode = scheduleCode
            self.courseID = courseID
            self.moduleID = moduleID
            self.scheduleID = scheduleID
            self.onComplete = onComplete
            self.attendanceContext = attendanceContext
        }
    }

    /// Identifiers plus the attendance date/status picked on the Attendance tab, used to
    /// build the `ILTTrainingAttendance` insert body. `date`/`statusCode` stay optional
    /// even though the tab switch gates them — the view model must not trust the view.
    struct NominateAttendanceContext {
        let scheduleID: Int
        let moduleID: Int
        let courseID: Int
        let date: Date?
        let statusCode: String?
    }
}
