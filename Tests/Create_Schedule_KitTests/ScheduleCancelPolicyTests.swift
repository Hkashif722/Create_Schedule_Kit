//
//  ScheduleCancelPolicyTests.swift
//  Create_Schedule_KitTests
//
//  `Enable_PastScheduleCancel` ("Allow to cancel past schedules for an ILT Course?") lets
//  an org cancel schedules whose time has passed. These pin what it does and does not lift.
//

import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct ScheduleCancelPolicyTests {

    // MARK: - Fixtures

    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func apiDay(_ offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return apiFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private static func schedule(
        registrationEndDate: String? = nil,
        scheduleType: String? = "Scheduled",
        startDaysFromToday: Int = 3,
        endDaysFromToday: Int = 3
    ) -> ScheduleListDataModel.Schedule {
        .init(
            id: 4127, scheduleCode: "SC8539", moduleName: "19965_Team Building Course",
            courseName: "Team Building", startDate: apiDay(startDaysFromToday),
            endDate: apiDay(endDaysFromToday), startTime: "09:00:00", endTime: "17:00:00",
            city: "gujrat", placeName: "Gujrat", academyAgencyName: "Gujrat",
            participantsCount: 3, moduleId: 42182, courseID: 56288, courseCode: nil,
            registrationEndDate: registrationEndDate, seatCapacity: nil, scheduleCapacity: nil,
            contactPersonName: nil, trainerType: nil, academyTrainerName: nil,
            trainerDescription: nil, scheduleType: scheduleType, purpose: nil, timezone: nil,
            isWebinar: nil, webinarType: nil
        )
    }

    /// Finished a week ago, registration long closed — the schedule the setting is for.
    private static var pastSchedule: ScheduleListDataModel.Schedule {
        schedule(registrationEndDate: apiDay(-10), startDaysFromToday: -7, endDaysFromToday: -7)
    }

    /// Upcoming, but registration closed yesterday.
    private static var closedRegistrationSchedule: ScheduleListDataModel.Schedule {
        schedule(registrationEndDate: apiDay(-1), startDaysFromToday: 3, endDaysFromToday: 3)
    }

    // MARK: - Setting off (the default, and what a config outage leaves in place)

    @Test func aFinishedScheduleIsRefusedWithoutTheSetting() {
        let refusal = ScheduleCancelPolicy.refusal(for: Self.pastSchedule, allowsPastCancel: false)
        #expect(refusal == .over)
        #expect(refusal?.message == "Schedule is over.")
    }

    @Test func aClosedRegistrationWindowIsRefusedWithoutTheSetting() {
        let refusal = ScheduleCancelPolicy.refusal(for: Self.closedRegistrationSchedule, allowsPastCancel: false)
        #expect(refusal == .registrationClosed)
    }

    @Test func aMissingRegistrationEndDateReadsAsClosed() {
        #expect(ScheduleCancelPolicy.refusal(for: Self.schedule(), allowsPastCancel: false) == .registrationClosed)
    }

    // MARK: - Setting on

    @Test func theSettingAllowsCancellingAFinishedSchedule() {
        #expect(ScheduleCancelPolicy.refusal(for: Self.pastSchedule, allowsPastCancel: true) == nil)
    }

    @Test func theSettingAllowsCancellingAfterRegistrationClosed() {
        #expect(ScheduleCancelPolicy.refusal(for: Self.closedRegistrationSchedule, allowsPastCancel: true) == nil)
    }

    @Test func theSettingAllowsAScheduleWithNoRegistrationEndDate() {
        #expect(ScheduleCancelPolicy.refusal(for: Self.schedule(), allowsPastCancel: true) == nil)
    }

    // MARK: - What the setting does not reach

    @Test(arguments: [false, true])
    func aTrainingInProgressIsAlwaysRefused(_ allowsPastCancel: Bool) {
        // Started yesterday, ends tomorrow: not a past schedule — the attendees are in the room.
        let ongoing = Self.schedule(
            registrationEndDate: Self.apiDay(-7), startDaysFromToday: -1, endDaysFromToday: 1
        )
        let refusal = ScheduleCancelPolicy.refusal(for: ongoing, allowsPastCancel: allowsPastCancel)

        #expect(refusal == .inProgress)
        #expect(refusal?.isLiftedByPastScheduleCancel == false)
    }

    @Test(arguments: [false, true])
    func anAlreadyCancelledScheduleIsAlwaysRefused(_ allowsPastCancel: Bool) {
        let cancelled = Self.schedule(
            registrationEndDate: Self.apiDay(5), scheduleType: "Cancelled"
        )
        let refusal = ScheduleCancelPolicy.refusal(for: cancelled, allowsPastCancel: allowsPastCancel)

        #expect(refusal == .alreadyCancelled)
        // Stated as a fact rather than an error.
        #expect(refusal?.isInformational == true)
        #expect(refusal?.isLiftedByPastScheduleCancel == false)
    }

    @Test func onlyTheDateBasedRefusalsAreLiftable() {
        #expect(ScheduleCancelPolicy.Refusal.over.isLiftedByPastScheduleCancel)
        #expect(ScheduleCancelPolicy.Refusal.registrationClosed.isLiftedByPastScheduleCancel)
        #expect(ScheduleCancelPolicy.Refusal.inProgress.isLiftedByPastScheduleCancel == false)
        #expect(ScheduleCancelPolicy.Refusal.alreadyCancelled.isLiftedByPastScheduleCancel == false)
    }

    // MARK: - Unaffected either way

    @Test(arguments: [false, true])
    func anUpcomingScheduleInsideItsWindowIsAllowed(_ allowsPastCancel: Bool) {
        let upcoming = Self.schedule(registrationEndDate: Self.apiDay(2))
        #expect(ScheduleCancelPolicy.refusal(for: upcoming, allowsPastCancel: allowsPastCancel) == nil)
    }

    @Test func theSettingReadsOnlyAnExplicitYes() throws {
        // Same fail-closed contract the other config codes use.
        func response(_ value: String?) throws -> ScheduleListDataModel.ConfigValueResponse {
            let object: [String: Any] = ["value": value ?? NSNull()]
            let data = try JSONSerialization.data(withJSONObject: object)
            return try JSONDecoder().decode(ScheduleListDataModel.ConfigValueResponse.self, from: data)
        }

        #expect(try response("Yes").isYes)
        #expect(try response("No").isYes == false)
        #expect(try response(nil).isYes == false)
    }
}
