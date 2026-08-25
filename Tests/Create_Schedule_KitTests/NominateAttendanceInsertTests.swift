import Testing
import Foundation
import SwiftfulRouting
import SwiftUIUtilities
@testable import Create_Schedule_Kit

/// Nominating from the Update Attendance screen inserts attendance rows instead of creating
/// nominations — a back-dated schedule cannot be nominated for. These pin the wire contract
/// of that insert (which is case-sensitive and shares a controller with a *different*
/// endpoint) and the date/status gate in front of it.
@Suite struct NominateAttendanceInsertTests {

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

    // MARK: - Helpers

    private func encodeToObject<T: Encodable>(_ payload: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return object as? [String: Any] ?? [:]
    }

    /// Midnight on the given day in the device timezone — the same thing the date picker produces.
    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = dayOfMonth
        return try #require(Calendar.current.date(from: components))
    }

    private func insertItem(
        statusCode: String = "ATTD",
        attendanceDate: String = "2026-08-06T00:00:00.000Z"
    ) -> AttendanceDataModel.InsertItem {
        .init(
            id: 0,
            isPresent: statusCode == "ATTD",
            userId: 11985,
            moduleId: 46289,
            scheduleId: 4092,
            courseId: 59207,
            isweb: true,
            attendanceStatus: statusCode,
            attendanceDate: attendanceDate,
            withdrewReason: "",
            withdrewRemark: ""
        )
    }

    @MainActor
    private func attendanceViewModel() -> AttendanceViewModel {
        AttendanceViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                scheduleID: 4092, courseID: 59207, moduleID: 46289,
                courseName: "Course", moduleName: "Module",
                scheduleCode: "SC8450", dateRangeText: "Aug 06, 2026"
            )
        )
    }

    private func statusOption(_ code: String) -> AttendanceDataModel.AttendanceStatusOption {
        .init(valueCode: code, valueName: code == "ATTD" ? "Attended" : code, sequence: 1, isDeleted: false)
    }

    // MARK: - Payload wire format

    @Test func insertPayloadMatchesTheServerSample() throws {
        let object = try encodeToObject(insertItem())

        #expect(object.count == 11)
        #expect(object["id"] as? Int == 0)
        #expect(object["IsPresent"] as? Bool == true)
        #expect(object["userId"] as? Int == 11985)
        #expect(object["moduleId"] as? Int == 46289)
        #expect(object["scheduleId"] as? Int == 4092)
        #expect(object["courseId"] as? Int == 59207)
        #expect(object["isweb"] as? Bool == true)
        #expect(object["attendanceStatus"] as? String == "ATTD")
        #expect(object["AttendanceDate"] as? String == "2026-08-06T00:00:00.000Z")
    }

    /// `IsPresent` and `AttendanceDate` are PascalCase while the rest are camelCase. The
    /// server does not report a mapping mistake, so the casing is pinned here.
    @Test func insertPayloadKeysAreNotUniformlyCamelCased() throws {
        let object = try encodeToObject(insertItem())

        #expect(object["isPresent"] == nil)
        #expect(object["attendanceDate"] == nil)
        #expect(object.keys.contains("IsPresent"))
        #expect(object.keys.contains("AttendanceDate"))
    }

    /// This endpoint wants empty strings, not nulls. JSONSerialization cannot tell an absent
    /// key from a null, so the raw JSON is checked too.
    @Test func withdrewFieldsAreEmptyStringsNotNull() throws {
        let object = try encodeToObject(insertItem())
        #expect(object["withdrewReason"] as? String == "")
        #expect(object["withdrewRemark"] as? String == "")

        let raw = try #require(String(data: try JSONEncoder().encode(insertItem()), encoding: .utf8))
        #expect(raw.contains("\"withdrewReason\":\"\""))
        #expect(raw.contains("\"withdrewRemark\":\"\""))
    }

    /// `isPresent` is derived from the status code rather than sent independently.
    @Test(arguments: [("ATTD", true), ("ABS", false), ("WD", false), ("LATE", false)])
    func isPresentFollowsTheAttendanceStatus(code: String, expected: Bool) throws {
        let object = try encodeToObject(insertItem(statusCode: code))
        #expect(object["IsPresent"] as? Bool == expected)
        #expect(object["attendanceStatus"] as? String == code)
    }

    /// The body is sent as a JSON array, not a bare object.
    @Test func insertBodyEncodesAsAnArray() throws {
        let data = try JSONEncoder().encode([insertItem()])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(array?.count == 1)
        #expect(array?.first?["userId"] as? Int == 11985)
    }

    // MARK: - Route

    /// The insert lives on the bare controller path — both the Attendance screen's Save and
    /// the embedded Nominate tab post there. Pinned because a stray trailing path segment
    /// would silently retarget every attendance save.
    @Test func insertAttendanceRouteIsTheBareControllerPath() {
        let insert = AttendanceDataModel.InsertAttendanceRequest()

        #expect(insert.path == "/api/v1/ILTTrainingAttendance")
        #expect(insert.method == .post)
    }

    // MARK: - Response

    @Test func insertResponseDecodesIntoTheSharedNominateEnvelope() throws {
        let json = """
        {
            "statusCode": 200,
            "message": null,
            "responseObject": null,
            "description": "Total Inserted: 1, Updated: 0 and Rejected: 0.",
            "aPINominationResponses": [
                {
                    "courseName": null,
                    "batchCode": null,
                    "moduleName": "19908_ios-schedul-01",
                    "scheduleCode": "SC8450",
                    "userId": "twouser",
                    "userName": "twouser",
                    "status": "Inserted",
                    "errorMessage": null
                }
            ]
        }
        """
        let response = try JSONDecoder().decode(
            NominateUsersDataModel.NominateResponse.self, from: Data(json.utf8)
        )

        #expect(response.statusCode == 200)
        #expect(response.message == nil)
        #expect(response.description == "Total Inserted: 1, Updated: 0 and Rejected: 0.")
        #expect(response.aPINominationResponses?.count == 1)
        #expect(response.aPINominationResponses?.first?.status == "Inserted")
        #expect(response.aPINominationResponses?.first?.userId == "twouser")
        #expect(response.aPINominationResponses?.first?.errorMessage == nil)
    }

    // MARK: - Date helper

    @Test func isoDayStartNamesThePickedCalendarDay() throws {
        #expect(try day(2026, 8, 6).isoDayStartUTCString == "2026-08-06T00:00:00.000Z")
    }

    /// The time is zeroed rather than truncated, so any instant on the day yields the same string.
    @Test func isoDayStartZeroesTheTimeOfDay() throws {
        let midnight = try day(2026, 8, 6)
        let afternoon = try #require(Calendar.current.date(byAdding: .hour, value: 15, to: midnight))
        #expect(afternoon.isoDayStartUTCString == midnight.isoDayStartUTCString)
    }

    /// The wizard now delegates to the shared helper — this keeps its payload byte-stable.
    @Test func wizardIsoDateAgreesWithTheSharedHelper() throws {
        let date = try day(2026, 6, 24)
        #expect(CreateScheduleWizardDataModel.Payload.isoDate(date) == date.isoDayStartUTCString)
        #expect(CreateScheduleWizardDataModel.Payload.isoDate(date) == "2026-06-24T00:00:00.000Z")
    }

    // MARK: - Tab gate

    @MainActor
    @Test func nominateTabIsBlockedUntilTheDateIsPicked() {
        let viewModel = attendanceViewModel()
        viewModel.selectedStatus = statusOption("ATTD")

        viewModel.selectTab(.nominate)

        #expect(viewModel.activeTab == .attendance)
        #expect(viewModel.toast?.message == "Please select the attendance date.")
    }

    @MainActor
    @Test func nominateTabIsBlockedUntilTheStatusIsPicked() throws {
        let viewModel = attendanceViewModel()
        viewModel.selectedDate = try day(2026, 8, 6)

        viewModel.selectTab(.nominate)

        #expect(viewModel.activeTab == .attendance)
        #expect(viewModel.toast?.message == "Please select the attendance status.")
    }

    @MainActor
    @Test func nominateTabOpensOnceDateAndStatusAreSet() throws {
        let viewModel = attendanceViewModel()
        viewModel.selectedDate = try day(2026, 8, 6)
        viewModel.selectedStatus = statusOption("ATTD")

        #expect(viewModel.nominateBlockReason == nil)
        viewModel.selectTab(.nominate)
        #expect(viewModel.activeTab == .nominate)
    }

    /// Switching back is never gated.
    @MainActor
    @Test func attendanceTabIsAlwaysReachable() {
        let viewModel = attendanceViewModel()
        viewModel.selectTab(.attendance)
        #expect(viewModel.activeTab == .attendance)
    }

    // MARK: - Submit gate

    @MainActor
    private func nominateViewModel(
        context: (() -> NavigationViewModel.NominateAttendanceContext)?
    ) -> NominateUsersViewModel {
        NominateUsersViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                scheduleCode: "SC8450",
                courseID: 59207,
                moduleID: 46289,
                onComplete: {},
                attendanceContext: context
            )
        )
    }

    private var nominationUser: NominateUsersDataModel.NominationUser {
        get throws {
            let json = """
            {"ID": 11985, "UserId": "twouser", "UserName": "twouser",
             "EmailId": "two@example.com", "MobileNumber": "", "Status": null}
            """
            return try JSONDecoder().decode(
                NominateUsersDataModel.NominationUser.self, from: Data(json.utf8)
            )
        }
    }

    /// The attendance guards must run *before* the "schedule still loading" guard, otherwise
    /// the user sees the wrong message on a screen that has no schedule id of its own.
    @MainActor
    @Test func attendanceSubmitIsBlockedWithoutADate() throws {
        let viewModel = nominateViewModel(context: {
            .init(scheduleID: 4092, moduleID: 46289, courseID: 59207, date: nil, statusCode: "ATTD")
        })
        viewModel.toggle(try nominationUser)

        viewModel.didTapNominate()

        #expect(viewModel.toast?.message == "Please select the attendance date.")
    }

    @MainActor
    @Test func attendanceSubmitIsBlockedWithoutAStatus() throws {
        let date = try day(2026, 8, 6)
        let viewModel = nominateViewModel(context: {
            .init(scheduleID: 4092, moduleID: 46289, courseID: 59207, date: date, statusCode: nil)
        })
        viewModel.toggle(try nominationUser)

        viewModel.didTapNominate()

        #expect(viewModel.toast?.message == "Please select the attendance status.")
    }

    /// Cancel in the embedded tab must not pop the host Update Attendance screen — it only
    /// drops the selection.
    @MainActor
    @Test func cancelInAttendanceModeOnlyClearsTheSelection() throws {
        let viewModel = nominateViewModel(context: {
            .init(scheduleID: 4092, moduleID: 46289, courseID: 59207, date: nil, statusCode: "ATTD")
        })
        viewModel.toggle(try nominationUser)
        #expect(viewModel.isNominateEnabled)

        viewModel.didTapCancel()

        #expect(viewModel.selectedUsers.isEmpty)
    }

    /// The wizard and schedule-detail call shapes must keep compiling without a context, and
    /// must stay on the nomination API.
    @MainActor
    @Test func otherEntryPointsCarryNoAttendanceContext() {
        let wizard = NavigationViewModel.NominateUsersNavModel(
            scheduleCode: "SC8450", courseID: 59207, moduleID: 46289, onComplete: {}
        )
        let detail = NavigationViewModel.NominateUsersNavModel(
            scheduleCode: "SC8450", courseID: 59207, moduleID: 46289,
            scheduleID: 4092, onComplete: {}
        )

        #expect(wizard.attendanceContext == nil)
        #expect(detail.attendanceContext == nil)
    }
}
