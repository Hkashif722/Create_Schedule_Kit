//
//  AttendanceActionGatingTests.swift
//  Create_Schedule_KitTests
//
//  Update Attendance owns the date and nothing else, so every way of marking someone has to
//  refuse until a date is picked. All three are always offered — scanning a learner's QR and
//  handing out the schedule's QR are part of marking attendance, not a licensed extra.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct AttendanceActionGatingTests {

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
    private func viewModel() -> AttendanceViewModel {
        AttendanceViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                scheduleID: 3787, courseID: 56288, moduleID: 42182,
                courseName: "ELGI Live Class", moduleName: "20651_ELGI Live Class",
                scheduleCode: "SC9202", dateRangeText: "Sep 09, 2026"
            )
        )
    }

    // MARK: - The date gates every way of marking

    @MainActor
    @Test func noDateIsPickedWhenTheScreenOpens() {
        let model = viewModel()
        #expect(model.selectedDate == nil)
        #expect(model.markBlockReason == "Please select the attendance date.")
    }

    @MainActor
    @Test func bulkMarkIsRefusedUntilTheDateIsPicked() throws {
        let model = viewModel()

        model.didTapBulkMark()

        let toast = try #require(model.toast)
        #expect(toast.message == "Please select the attendance date.")
        #expect(toast.style == .warning)
    }

    @MainActor
    @Test func scanQRIsRefusedUntilTheDateIsPicked() throws {
        let model = viewModel()

        model.didTapScanQR()

        #expect(try #require(model.toast).message == "Please select the attendance date.")
    }

    @MainActor
    @Test func downloadIsRefusedUntilTheDateIsPicked() throws {
        let model = viewModel()

        model.didTapDownload()

        #expect(try #require(model.toast).message == "Please select the attendance date.")
    }

    @MainActor
    @Test func theAttendeesListOpensWithoutADate() {
        // It is about who is on the schedule, not about a particular day.
        let model = viewModel()

        model.didTapAttendees()

        #expect(model.toast == nil)
    }

    @MainActor
    @Test func aPickedDateClearsTheBlock() {
        let model = viewModel()
        // Bounds are unknown until the schedule loads, so any day is selectable here.
        model.didSelectDate(Date())

        #expect(model.selectedDate != nil)
        #expect(model.markBlockReason == nil)
        #expect(model.toast == nil)
    }

    // MARK: - Every action is offered

    @MainActor
    @Test func allThreeWaysOfMarkingAreAvailableOnceADateIsPicked() {
        // Nothing gates Scan QR or Download: handing out the schedule's QR and scanning a
        // learner's are part of the trainer's job. `m_qrcode` is the *learner's* menu
        // permission and has no bearing here.
        let model = viewModel()
        model.didSelectDate(Date())

        model.didTapScanQR()
        model.didTapBulkMark()
        model.didTapDownload()
        model.didTapAttendees()

        #expect(model.toast == nil)
    }

}
