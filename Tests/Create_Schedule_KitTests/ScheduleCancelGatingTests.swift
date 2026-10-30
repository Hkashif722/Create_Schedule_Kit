//
//  ScheduleCancelGatingTests.swift
//  Create_Schedule_KitTests
//
//  The Cancel Schedule button is always on the card, so the refusal path is a toast rather than a
//  hidden control. These pin that refusal — and the `Enable_PastScheduleCancel` override that
//  lifts it.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleCancelGatingTests {

    private static let refusalMessage = "Training cannot be canceled, as training already started."

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
    @Test(arguments: [1, 5, 30])
    func cancellingAfterRegistrationEndIsRefusedWithAToast(daysAgo: Int) throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        let schedule = try Self.schedule(registrationEndDaysAgo: daysAgo)

        #expect(viewModel.toast == nil)

        viewModel.didTapCancel(schedule)

        let toast = try #require(viewModel.toast)
        #expect(toast.message == Self.refusalMessage)
        #expect(toast.style == .error)
    }

    /// Inside the registration window there is nothing to refuse — the sheet is presented, so no
    /// toast is set. (The router here is the environment default, whose navigation calls are
    /// no-ops, so the absence of a toast is the only observable outcome.)
    @MainActor
    @Test(arguments: [0, 1, 5])
    func cancellingWithinTheRegistrationWindowIsAllowed(daysUntilRegistrationEnd: Int) throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        let schedule = try Self.schedule(registrationEndDaysAgo: -daysUntilRegistrationEnd)

        viewModel.didTapCancel(schedule)

        #expect(viewModel.toast == nil)
    }

    /// The gate reads a date-only payload too, so a format change cannot silently disable
    /// cancellation for every row.
    @MainActor
    @Test(arguments: [("2099-01-01", true), ("2099-01-01T00:00:00", true), ("2000-01-01", false)])
    func dateOnlyRegistrationEndStillParses(raw: String, expectedOpen: Bool) {
        let schedule = Self.schedule(registrationEndDate: raw)

        #expect(schedule.isWithinRegistrationWindow == expectedOpen)
        #expect(schedule.registrationEndDateValue != nil)
    }

    /// A schedule with no registration end date reads as closed, so it is refused unless the org
    /// enables past-schedule cancellation.
    @MainActor
    @Test func missingRegistrationEndDateIsRefused() throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)

        viewModel.didTapCancel(Self.schedule(registrationEndDate: nil))

        #expect(viewModel.toast?.message == Self.refusalMessage)
    }

    // MARK: - The schedule's own progress

    /// A same-day training keeps an open registration window all day, so the window alone let a
    /// finished schedule be cancelled. Its end moment is what refuses it.
    @MainActor
    @Test(arguments: [1, 5, 30])
    func cancellingACompletedScheduleIsRefused(daysAgo: Int) throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        // Registration is still open (ends in a week), so only "over" can block this.
        let schedule = try Self.schedule(
            registrationEndDaysAgo: -7,
            startDaysFromToday: -daysAgo,
            endDaysFromToday: -daysAgo
        )

        viewModel.didTapCancel(schedule)

        let toast = try #require(viewModel.toast)
        #expect(toast.message == "Schedule is over.")
        #expect(toast.style == .error)
    }

    /// The exact repro from the report: a schedule created, run and finished on the same day,
    /// whose registration end date is that same day.
    @MainActor
    @Test func cancellingATrainingThatFinishedEarlierTodayIsRefused() throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        let schedule = Self.schedule(
            registrationEndDate: Self.apiDay(0),
            startDaysFromToday: 0,
            endDaysFromToday: 0,
            startTime: "00:00:00",
            endTime: "00:01:00"
        )

        #expect(schedule.isWithinRegistrationWindow)   // the old gate would have allowed it
        viewModel.didTapCancel(schedule)

        #expect(viewModel.toast?.message == "Schedule is over.")
    }

    /// Started but not finished — the trainees are in the room.
    @MainActor
    @Test func cancellingAnInProgressTrainingIsRefused() throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        let schedule = try Self.schedule(
            registrationEndDaysAgo: -7,
            startDaysFromToday: -1,
            endDaysFromToday: 1
        )

        #expect(schedule.status() == .ongoing)
        viewModel.didTapCancel(schedule)

        let toast = try #require(viewModel.toast)
        #expect(toast.message == "Training cannot be cancelled as training already started.")
        #expect(toast.style == .error)
    }

    /// A training that started earlier today and runs until this evening.
    @MainActor
    @Test func cancellingATrainingThatStartedEarlierTodayIsRefused() throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        let schedule = Self.schedule(
            registrationEndDate: Self.apiDay(0),
            startDaysFromToday: 0,
            endDaysFromToday: 0,
            startTime: "00:00:00",
            endTime: "23:59:00"
        )

        viewModel.didTapCancel(schedule)

        #expect(viewModel.toast?.message == "Training cannot be cancelled as training already started.")
    }

    /// An upcoming schedule inside its registration window is still cancellable — the fix must
    /// not close the door on the only case that should be open.
    @MainActor
    @Test(arguments: [1, 3, 30])
    func cancellingAnUpcomingScheduleIsStillAllowed(daysFromToday: Int) throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        let schedule = try Self.schedule(
            registrationEndDaysAgo: -daysFromToday,
            startDaysFromToday: daysFromToday,
            endDaysFromToday: daysFromToday
        )

        #expect(schedule.status() == .upcoming)
        viewModel.didTapCancel(schedule)

        #expect(viewModel.toast == nil)
    }

    // MARK: - Cancelled schedules are read-only

    /// `scheduleType` is how the server reports cancellation; the spelling varies by endpoint, so
    /// the match is a case-insensitive substring.
    @Test(arguments: [
        ("Scheduled", false),
        ("Cancelled", true),
        ("Canceled", true),
        ("CANCELLED", true),
        ("Cancellation", true),
        ("Rescheduled", false),   // must not false-positive on a word containing "schedule"
        (nil, false)
    ] as [(String?, Bool)])
    func cancellationIsDerivedFromScheduleType(scheduleType: String?, expected: Bool) {
        #expect(Self.schedule(scheduleType: scheduleType).isCancelled == expected)
    }

    /// Even reached with a stale row, an already-cancelled schedule cannot be cancelled again.
    @MainActor
    @Test func cancellingAnAlreadyCancelledScheduleIsRefused() throws {
        let viewModel = ScheduleListViewModel(router: RouterEnvironmentKey.defaultValue)
        // Registration still open, so only the cancelled state can block this.
        let schedule = try Self.schedule(registrationEndDaysAgo: -5, scheduleType: "Cancelled")

        viewModel.didTapCancel(schedule)

        let toast = try #require(viewModel.toast)
        #expect(toast.message == "This schedule is already cancelled.")
        #expect(toast.style == .info)
    }

    // MARK: - Fixtures

    /// Days from today, at midnight, in the API's `yyyy-MM-dd'T'HH:mm:ss` shape.
    private static func apiDay(_ daysFromToday: Int) -> String {
        let day = Calendar.current.date(
            byAdding: .day,
            value: daysFromToday,
            to: Calendar.current.startOfDay(for: Date())
        )!
        return apiFormatter.string(from: day)
    }

    private static func schedule(
        registrationEndDaysAgo days: Int,
        scheduleType: String? = "Scheduled",
        startDaysFromToday: Int = 3,
        endDaysFromToday: Int = 3
    ) throws -> ScheduleListDataModel.Schedule {
        let date = try #require(Calendar.current.date(byAdding: .day, value: -days, to: Date()))
        return schedule(
            registrationEndDate: apiFormatter.string(from: date),
            scheduleType: scheduleType,
            startDaysFromToday: startDaysFromToday,
            endDaysFromToday: endDaysFromToday
        )
    }

    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Defaults to a schedule three days out, so only the gate a test is exercising can fire.
    private static func schedule(
        registrationEndDate: String? = nil,
        scheduleType: String? = "Scheduled",
        startDaysFromToday: Int = 3,
        endDaysFromToday: Int = 3,
        startTime: String? = "09:00:00",
        endTime: String? = "17:00:00"
    ) -> ScheduleListDataModel.Schedule {
        .init(
            id: 4127, scheduleCode: "SC8539", moduleName: "19965_Team Building Course",
            courseName: "Team Building", startDate: apiDay(startDaysFromToday),
            endDate: apiDay(endDaysFromToday), startTime: startTime, endTime: endTime,
            city: "gujrat", placeName: "Gujrat", academyAgencyName: "Gujrat",
            participantsCount: 3, moduleId: 42182, courseID: 56288, courseCode: nil,
            registrationEndDate: registrationEndDate, seatCapacity: nil, scheduleCapacity: nil,
            contactPersonName: nil, trainerType: nil, academyTrainerName: nil,
            trainerDescription: nil, scheduleType: scheduleType, purpose: nil, timezone: nil,
            isWebinar: nil, webinarType: nil
        )
    }
}
