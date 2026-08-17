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

    // MARK: - Schedule details
    struct ScheduleDetailNavModel {
        let schedule: ScheduleListDataModel.Schedule
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

    // MARK: - Nominate users bottom sheet
    // Presented after a schedule is created (if the creator opts to nominate). Carries the
    // just-created schedule's identifiers; `onComplete` finishes the wizard afterwards.
    struct NominateUsersNavModel {
        let scheduleCode: String
        let courseID: Int
        let moduleID: Int
        let scheduleID: Int?
        let onComplete: () -> Void
        
        init(scheduleCode: String, courseID: Int, moduleID: Int, scheduleID: Int? = nil, onComplete: @escaping () -> Void) {
            self.scheduleCode = scheduleCode
            self.courseID = courseID
            self.moduleID = moduleID
            self.scheduleID = scheduleID
            self.onComplete = onComplete
        }
    }
}
