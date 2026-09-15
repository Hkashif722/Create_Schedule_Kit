//
//  BulkMarkAttendanceGatingTests.swift
//  Create_Schedule_KitTests
//
//  Save is always on the footer, so every refusal is a toast rather than a hidden control.
//
//  Bug this suite exists for: attendance was recorded as Attended without a status ever
//  being chosen. Two things caused it — the status list pre-selected its first option, and
//  the payload fell back to `ATTD` when nothing was selected.
//
//  Since the flow split, the date is chosen on Update Attendance and arrives on the nav
//  model, so the date refusals here are the defensive path — worth keeping for exactly that.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct BulkMarkAttendanceGatingTests {

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

    private static let attended = AttendanceDataModel.AttendanceStatusOption(
        valueCode: AttendanceDataModel.StatusCode.attended,
        valueName: "Attended",
        sequence: 1,
        isDeleted: false
    )

    private static func navModel(
        mode: AttendanceUsersMode = .bulkMark,
        date: Date? = Date()
    ) -> NavigationViewModel.AttendanceUsersNavModel {
        .init(
            mode: mode,
            scheduleID: 4122,
            courseID: 59245,
            moduleID: 46399,
            scheduleCode: "SC8795",
            attendanceDate: date,
            onAttendanceChanged: {}
        )
    }

    @MainActor
    private func viewModel(
        mode: AttendanceUsersMode = .bulkMark,
        date: Date? = Date(),
        permissions: SchedulePermissions = SchedulePermissions(userRole: "")
    ) -> AttendanceUsersViewModel {
        AttendanceUsersViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: Self.navModel(mode: mode, date: date),
            permissions: permissions
        )
    }

    // MARK: - Save gating

    @MainActor
    @Test func noStatusIsChosenForTheUser() {
        // The dropdown reads "Select status", so nothing may be selected behind it.
        #expect(viewModel().selectedStatus == nil)
    }

    @MainActor
    @Test func savingWithoutAStatusIsRefusedWithAToast() throws {
        let model = viewModel()

        model.didTapSave()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select the attendance status.")
        #expect(toast.style == .warning)
    }

    @MainActor
    @Test func savingWithoutADateIsRefusedFirst() throws {
        // Defensive: the date comes from the previous screen, so this should be unreachable.
        let model = viewModel(date: nil)
        model.selectStatus(Self.attended)

        model.didTapSave()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select the attendance date.")
    }

    @MainActor
    @Test func withADateAndStatusTheRefusalMovesOnToTheUserList() throws {
        let model = viewModel()
        model.selectStatus(Self.attended)

        model.didTapSave()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select at least one user.")
    }

    @MainActor
    @Test func theDateComesFromTheNavModelNotTheScreen() {
        let day = Date(timeIntervalSince1970: 1_788_000_000)
        #expect(viewModel(date: day).attendanceDate == day)
        #expect(viewModel(date: nil).attendanceDate == nil)
    }

    @MainActor
    @Test func saveStaysDisabledUntilThereIsADateAndASelection() {
        // The footer's own enablement, independent of the toasts above.
        #expect(viewModel().isSaveEnabled == false)
        #expect(viewModel(date: nil).isSaveEnabled == false)
    }

    // MARK: - The Nomination tab

    @MainActor
    @Test func theNominateTabStaysShutUntilAStatusIsChosen() {
        let model = viewModel()

        #expect(model.nominateBlockReason == "Please select the attendance status.")

        model.selectStatus(Self.attended)
        #expect(model.nominateBlockReason == nil)
    }

    @MainActor
    @Test func nominateTabIsBlockedUntilTheDateIsPicked() {
        // Moved from NominateAttendanceInsertTests: the tabs live here now.
        #expect(viewModel(date: nil).nominateBlockReason == "Please select the attendance date.")
    }

    @MainActor
    @Test func nominateTabOpensOnceDateAndStatusAreSet() {
        let model = viewModel()
        model.selectStatus(Self.attended)

        model.selectTab(.nominate)

        #expect(model.activeTab == .nominate)
        #expect(model.toast == nil)
    }

    @MainActor
    @Test func selectingTheNominateTabWithoutAStatusRefusesAndStaysPut() throws {
        let model = viewModel()

        model.selectTab(.nominate)

        #expect(model.activeTab == .attendance)
        #expect(try #require(model.toast).message == "Please select the attendance status.")
    }

    @MainActor
    @Test func attendanceTabIsAlwaysReachable() {
        let model = viewModel()
        model.selectTab(.attendance)
        #expect(model.activeTab == .attendance)
    }

    @MainActor
    @Test func aChosenStatusReachesTheNominateInsertContext() {
        let model = viewModel()
        model.selectStatus(Self.attended)
        #expect(model.selectedStatus?.valueCode == AttendanceDataModel.StatusCode.attended)
    }

    @MainActor
    @Test func theNominationTabIsNotOfferedToAnExternalTrainer() {
        // An ET marks attendance but cannot nominate, so the bar collapses to one tab.
        let model = viewModel(permissions: SchedulePermissions(userRole: "ET"))

        #expect(model.availableTabs == [.attendance])
        model.selectTab(.nominate)
        #expect(model.activeTab == .attendance)
    }
}
