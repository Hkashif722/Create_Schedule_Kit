//
//  AttendanceSaveGatingTests.swift
//  Create_Schedule_KitTests
//
//  Save is always on the footer, so every refusal is a toast rather than a hidden control.
//
//  Bug: attendance was recorded as Attended without a status ever being chosen. Two things
//  caused it — the status list pre-selected its first option ("Attended"), and Save's
//  payload fell back to `ATTD` when nothing was selected. These pin both shut.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct AttendanceSaveGatingTests {

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

    private static let navModel = NavigationViewModel.AttendanceNavModel(
        scheduleID: 4122,
        courseID: 59245,
        moduleID: 46399,
        courseName: "Test ILT006",
        moduleName: "8729_Test ILT006",
        scheduleCode: "SC8795",
        dateRangeText: "Sep 02, 2026"
    )

    private static let attended = AttendanceDataModel.AttendanceStatusOption(
        valueCode: AttendanceDataModel.StatusCode.attended,
        valueName: "Attended",
        sequence: 1,
        isDeleted: false
    )

    @MainActor
    private func viewModel() -> AttendanceViewModel {
        AttendanceViewModel(router: RouterEnvironmentKey.defaultValue, navModel: Self.navModel)
    }

    @MainActor
    @Test func noStatusIsChosenForTheUser() {
        // The dropdown reads "Select status", so nothing may be selected behind it.
        #expect(viewModel().selectedStatus == nil)
    }

    @MainActor
    @Test func savingWithoutAStatusIsRefusedWithAToast() throws {
        let model = viewModel()
        model.didSelectDate(Date())
        model.toast = nil

        model.didTapSave()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select the attendance status.")
        #expect(toast.style == .warning)
    }

    @MainActor
    @Test func savingWithoutADateIsRefusedFirst() throws {
        let model = viewModel()
        model.selectStatus(Self.attended)

        model.didTapSave()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select the attendance date.")
    }

    @MainActor
    @Test func theNominateTabStaysShutUntilAStatusIsChosen() throws {
        let model = viewModel()
        model.didSelectDate(Date())

        #expect(model.nominateBlockReason == "Please select the attendance status.")

        model.selectStatus(Self.attended)
        #expect(model.nominateBlockReason == nil)
    }

    @MainActor
    @Test func withADateAndStatusTheRefusalMovesOnToTheUserList() throws {
        let model = viewModel()
        model.didSelectDate(Date())
        model.selectStatus(Self.attended)
        model.toast = nil

        model.didTapSave()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select at least one user.")
    }

    @MainActor
    @Test func aChosenStatusReachesTheNominateInsertContext() {
        let model = viewModel()
        model.selectStatus(Self.attended)
        #expect(model.selectedStatus?.valueCode == AttendanceDataModel.StatusCode.attended)
    }
}
