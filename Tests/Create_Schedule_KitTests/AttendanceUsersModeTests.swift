//
//  AttendanceUsersModeTests.swift
//  Create_Schedule_KitTests
//
//  Bulk Mark and Attendees share one view model; this enum is the whole contract between
//  them, so what each mode turns on is pinned here rather than left to the two views.
//

import Testing
@testable import Create_Schedule_Kit

@Suite struct AttendanceUsersModeTests {

    @Test func bulkMarkSelectsAndSavesWhileAttendeesOnlyReads() {
        #expect(AttendanceUsersMode.bulkMark.isSelectable)
        #expect(AttendanceUsersMode.bulkMark.showsSaveFooter)

        #expect(AttendanceUsersMode.attendees.isSelectable == false)
        #expect(AttendanceUsersMode.attendees.showsSaveFooter == false)
    }

    @Test func onlyBulkMarkAsksForTheStatusOptions() {
        // Attendees writes nothing, so the ATTDSTATUS fetch would be wasted.
        #expect(AttendanceUsersMode.bulkMark.needsStatusOptions)
        #expect(AttendanceUsersMode.attendees.needsStatusOptions == false)
    }

    @Test func onlyBulkMarkOffersTheNominationTab() {
        // Nominating from here inserts attendance rows directly, which needs a status.
        #expect(AttendanceUsersMode.bulkMark.offersNominationTab)
        #expect(AttendanceUsersMode.attendees.offersNominationTab == false)
    }

    @Test func eachModeCarriesItsOwnTitle() {
        #expect(AttendanceUsersMode.bulkMark.title == "Bulk Mark Attendance")
        #expect(AttendanceUsersMode.attendees.title == "Attendees")
    }

    @Test func everyModeHasEmptyStateCopy() {
        #expect(AttendanceUsersMode.allCases.allSatisfy { !$0.emptyMessage.isEmpty })
        #expect(AttendanceUsersMode.allCases.allSatisfy { !$0.emptyIcon.isEmpty })
        #expect(AttendanceUsersMode.allCases.allSatisfy { !$0.sectionTitle.isEmpty })
    }
}
