//
//  CancelSchedulePayloadTests.swift
//  Create_Schedule_KitTests
//
//  Pins the cancel-schedule endpoints, the request body, the registration-window gate that
//  decides whether cancelling is offered at all, and the reason-field validation.
//

import Foundation
import NetworkService
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct CancelSchedulePayloadTests {

    init() {
        // Encrypting the schedule id reads the shared utility environment.
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

    private func encodeToObject<T: Encodable>(_ payload: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return object as? [String: Any] ?? [:]
    }

    // MARK: - Routes

    @Test func cancellationRouteMatchesTheDocumentedEndpoint() {
        let request = CancelScheduleDataModel.CancellationScheduleRequest()

        #expect(request.path == "/api/v1/ILTSchedule/CancellationSchedule")
        #expect(request.method == .post)
        #expect(request.headers == nil)
    }

    @Test func nominationCountRouteCarriesTheScheduleIDAsAPathParam() {
        let request = CancelScheduleDataModel.GetNominationCountDetailsRequest(scheduleID: 4127)

        #expect(request.path == "/api/v1/ILTSchedule/GetNominationCountDetails/4127")
        #expect(request.method == .get)
        #expect(request.headers == nil)
    }

    // MARK: - Payload

    @Test func cancelBodyCarriesExactlyTheScheduleIDAndReason() throws {
        let payload = CancelScheduleDataModel.CancelPayload(
            scheduleID: "anJbdxE14AVKZkxIZabyHQ==",
            reason: "cancel"
        )
        let object = try encodeToObject(payload)

        #expect(Set(object.keys) == ["scheduleID", "reason"])
        #expect(object["reason"] as? String == "cancel")
    }

    /// The encrypted id is an opaque base64 string — it must survive encoding byte for byte,
    /// including the `==` padding, and must not be re-encoded or escaped.
    @Test func encryptedScheduleIDIsPassedThroughVerbatim() throws {
        let encrypted = "anJbdxE14AVKZkxIZabyHQ=="
        let payload = CancelScheduleDataModel.CancelPayload(scheduleID: encrypted, reason: "cancel")
        let object = try encodeToObject(payload)

        #expect(object["scheduleID"] as? String == encrypted)

        let raw = try #require(String(data: try JSONEncoder().encode(payload), encoding: .utf8))
        #expect(raw.contains("anJbdxE14AVKZkxIZabyHQ=="))
    }

    // MARK: - Registration-window gate

    /// `isWithinRegistrationWindow` is day-granular on both sides, so the registration-end day
    /// itself still counts as open.
    @Test(arguments: [
        (-1, true),   // reg end is tomorrow      → open
        (0, true),    // reg end is today         → open (boundary)
        (1, false)    // reg end was yesterday    → closed
    ])
    func registrationWindowIncludesTheRegistrationEndDay(daysAgo: Int, expected: Bool) throws {
        let regEnd = try #require(
            Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())
        )
        let schedule = Self.schedule(registrationEndDate: Self.apiDateString(regEnd))

        #expect(schedule.isWithinRegistrationWindow == expected)
    }

    /// A missing or unparseable date reads as closed rather than silently allowing cancellation.
    /// Note `"2026-08-19"` is NOT in this list — the date-only form is a supported format, covered
    /// by `dateOnlyRegistrationEndStillParses` in `ScheduleCancelGatingTests`.
    @Test(arguments: [nil, "", "not-a-date", "19-08-2026"])
    func unusableRegistrationEndDateCountsAsClosed(raw: String?) {
        let schedule = Self.schedule(registrationEndDate: raw)

        #expect(schedule.isWithinRegistrationWindow == false)
        #expect(schedule.registrationEndDateValue == nil)
    }

    // MARK: - Reason validation

    @MainActor
    @Test(arguments: [
        ("123456789", false),          //  9 chars — below the floor
        ("1234567890", true),          // 10 chars — exactly the floor
        ("12345678901", true),         // 11 chars
        ("", false),
        ("          ", false),         // whitespace only
        ("  1234567890  ", true)       // trimmed to exactly the floor
    ])
    func submitIsEnabledOnlyOnceTheTrimmedReasonReachesTheMinimum(reason: String, expected: Bool) {
        let viewModel = Self.cancelViewModel()
        viewModel.reason = reason

        #expect(viewModel.isSubmitEnabled == expected)
    }

    @MainActor
    @Test func characterCountReportsRawLengthAgainstTheLimit() {
        let viewModel = Self.cancelViewModel()

        #expect(viewModel.characterCountText == "0/300")
        viewModel.reason = "Venue unavailable"
        #expect(viewModel.characterCountText == "17/300")
        #expect(CancelScheduleViewModel.reasonLimit == 300)
        #expect(CancelScheduleViewModel.reasonMinimum == 10)
    }

    @MainActor
    @Test func summaryFallsBackToADashWhenTheScheduleHasNoCodeOrModule() {
        let viewModel = Self.cancelViewModel(scheduleCode: "", moduleName: "")

        #expect(viewModel.scheduleCode == "-")
        #expect(viewModel.moduleName == "-")
    }

    // MARK: - Fixtures

    @MainActor
    private static func cancelViewModel(
        scheduleCode: String = "SC8539",
        moduleName: String = "19965_Team Building Course"
    ) -> CancelScheduleViewModel {
        CancelScheduleViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                scheduleID: 4127,
                scheduleCode: scheduleCode,
                moduleName: moduleName,
                onCancelled: {}
            )
        )
    }

    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func apiDateString(_ date: Date) -> String {
        apiFormatter.string(from: date)
    }

    private static func schedule(
        registrationEndDate: String?
    ) -> ScheduleListDataModel.Schedule {
        .init(
            id: 4127, scheduleCode: "SC8539", moduleName: "19965_Team Building Course",
            courseName: "Team Building", startDate: "2026-08-19T00:00:00",
            endDate: "2026-08-19T00:00:00", startTime: "14:03:00", endTime: "14:08:00",
            city: "gujrat", placeName: "Gujrat", academyAgencyName: "Gujrat",
            participantsCount: 3, moduleId: 42182, courseID: 56288, courseCode: nil,
            registrationEndDate: registrationEndDate, seatCapacity: nil, scheduleCapacity: nil,
            contactPersonName: nil, trainerType: nil, academyTrainerName: nil,
            trainerDescription: nil, scheduleType: nil, purpose: nil, timezone: nil,
            isWebinar: nil, webinarType: nil
        )
    }
}
