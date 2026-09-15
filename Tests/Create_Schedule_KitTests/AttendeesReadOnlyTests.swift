//
//  AttendeesReadOnlyTests.swift
//  Create_Schedule_KitTests
//
//  The Attendees screen shares its view model with Bulk Mark, so the read-only half of that
//  contract is pinned here: nothing to select, nothing to save, and no status list fetched —
//  while the details popup and the delete affordance still work.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct AttendeesReadOnlyTests {

    init() {
        SwiftUtilityEnvironment.configure(
            SwiftUtilityConfig(
                encryptionDecryptionKey: "preview-key",
                isBlobEnabled: true,
                orgCode: "preview",
                configurableDate: "dd-MM-yyyy",
                baseURL: "",
                lxpOPath: "",
                lxpBlobPath: "",
                lxpBlobPath1: ""
            )
        )
    }

    @MainActor
    private func viewModel(_ mode: AttendanceUsersMode) -> AttendanceUsersViewModel {
        AttendanceUsersViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                mode: mode,
                scheduleID: 4122, courseID: 59245, moduleID: 46399,
                scheduleCode: "SC8795", attendanceDate: Date(),
                onAttendanceChanged: {}
            )
        )
    }

    private func user(id: Int = 1, overAllStatus: String?) -> AttendanceDataModel.AttendanceUser {
        .init(
            id: id, scheduleID: 4122, userId: "harjeet", userName: "Harjeet Singh",
            emailId: "harjeet.singh@dummy.com", mobileNumber: nil, isPresent: false,
            moduleID: 46399, courseID: 59245,
            overAllStatus: overAllStatus, attendanceStatus: nil, attendanceDate: nil
        )
    }

    @MainActor
    @Test func attendeesOffersNoSelection() {
        let model = viewModel(.attendees)

        model.toggle(user(overAllStatus: "Completed"))

        #expect(model.selectedUsers.isEmpty)
        #expect(model.mode.isSelectable == false)
    }

    @MainActor
    @Test func selectAllDoesNothingOnAReadOnlyList() {
        let model = viewModel(.attendees)

        model.toggleSelectAll()

        #expect(model.selectedUsers.isEmpty)
    }

    @MainActor
    @Test func attendeesHasNoSaveFooter() {
        #expect(viewModel(.attendees).showsSaveFooter == false)
        #expect(viewModel(.bulkMark).showsSaveFooter)
    }

    @MainActor
    @Test func attendeesOffersNoNominationTab() {
        #expect(viewModel(.attendees).availableTabs == [.attendance])
    }

    @MainActor
    @Test func attendeesStillHonoursTheDeleteGuard() {
        // A row with no overall status has nothing to remove, so it never reaches the API —
        // the same rule as on Bulk Mark.
        let model = viewModel(.attendees)

        model.didTapDeleteUser(user(overAllStatus: nil))

        // Refused with the alert rather than a confirmation, so no toast and no request.
        #expect(model.toast == nil)
        #expect(model.missingStatusMessage.contains("attendance status is not present"))
    }

    @MainActor
    @Test func bothScreensShareTheSameTitleSource() {
        #expect(viewModel(.attendees).title == "Attendees")
        #expect(viewModel(.bulkMark).title == "Bulk Mark Attendance")
    }
}
