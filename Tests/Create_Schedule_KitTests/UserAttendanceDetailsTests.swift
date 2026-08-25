//
//  UserAttendanceDetailsTests.swift
//  Create_Schedule_KitTests
//
//  Covers the eye-button popup's wire contract: the `GetDetailsForUserAttendance` route, its
//  payload keys, and the response decoding + display formatting.
//

import Testing
import Foundation
import NetworkService
@testable import Create_Schedule_Kit

@Suite struct UserAttendanceDetailsTests {

    // MARK: - Helpers

    private func encodeToObject<T: Encodable>(_ payload: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return object as? [String: Any] ?? [:]
    }

    private func decodeDetails(_ json: String) throws -> [AttendanceDataModel.UserAttendanceDetail] {
        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode([AttendanceDataModel.UserAttendanceDetail].self, from: data)
    }

    /// The exact UAT response for a user with one attendance record.
    private let sampleResponse = """
    [
        {
            "attendanceDate": "2026-08-06T12:00:00",
            "attendanceStatus": "Attended",
            "withdrewReason": null,
            "withdrewRemark": null
        }
    ]
    """

    // MARK: - Payload

    @Test func payloadSendsExactlyTheFourExpectedKeys() throws {
        let object = try encodeToObject(
            AttendanceDataModel.UserAttendanceDetailPayload(
                scheduleID: 4092,
                courseId: 59207,
                moduleId: 46289,
                userId: 11987
            )
        )

        #expect(object.count == 4)
        #expect(object["scheduleID"] as? Int == 4092)
        #expect(object["courseId"] as? Int == 59207)
        #expect(object["moduleId"] as? Int == 46289)
        #expect(object["userId"] as? Int == 11987)
    }

    /// `scheduleID` keeps its capital `D` and the rest stay camelCase — the server rejects
    /// other casings.
    @Test func payloadDoesNotUseAlternateCasings() throws {
        let object = try encodeToObject(
            AttendanceDataModel.UserAttendanceDetailPayload(
                scheduleID: 1, courseId: 2, moduleId: 3, userId: 4
            )
        )

        #expect(object["scheduleId"] == nil)
        #expect(object["ScheduleID"] == nil)
        #expect(object["UserMasterId"] == nil)
        #expect(object["UserId"] == nil)
    }

    // MARK: - Route

    @Test func detailsRouteMatchesTheDocumentedEndpoint() {
        let request = AttendanceDataModel.GetDetailsForUserAttendanceRequest()

        #expect(request.path == "/api/v1/ILTTrainingAttendance/GetDetailsForUserAttendance")
        #expect(request.method == .post)
        #expect(request.headers == nil)
    }

    @Test func detailsRouteStaysDistinctFromTheOtherAttendanceRoutes() {
        let details = AttendanceDataModel.GetDetailsForUserAttendanceRequest().path

        #expect(details != AttendanceDataModel.InsertAttendanceRequest().path)
        #expect(details != AttendanceDataModel.AttendanceDeleteRequest().path)
        #expect(details != AttendanceDataModel.GetUsersForAttendanceRequest().path)
    }

    // MARK: - Decoding

    @Test func decodesTheSampleResponse() throws {
        let details = try decodeDetails(sampleResponse)

        #expect(details.count == 1)
        let record = try #require(details.first)
        #expect(record.attendanceDate == "2026-08-06T12:00:00")
        #expect(record.attendanceStatus == "Attended")
        #expect(record.withdrewReason == nil)
        #expect(record.withdrewRemark == nil)
    }

    @Test func decodesAnEmptyResponse() throws {
        #expect(try decodeDetails("[]").isEmpty)
    }

    @Test func decodesWithdrewFieldsWhenPresent() throws {
        let details = try decodeDetails("""
        [{ "attendanceDate": "2026-08-07T12:00:00", "attendanceStatus": "Withdrew",
           "withdrewReason": "Personal", "withdrewRemark": "Family event" }]
        """)

        let record = try #require(details.first)
        #expect(record.withdrewReason == "Personal")
        #expect(record.withdrewRemark == "Family event")
    }

    /// The list endpoint's rows and this endpoint's rows disagree on `attendanceStatus`: the
    /// former sends the `ATTD` code, the latter the display name. The popup must not translate.
    @Test func statusArrivesAsADisplayNameNotACode() throws {
        let record = try #require(try decodeDetails(sampleResponse).first)

        #expect(record.statusText == "Attended")
    }

    // MARK: - Display formatting

    @Test func dateTextMatchesTheWebModalFormat() throws {
        let record = try #require(try decodeDetails(sampleResponse).first)

        #expect(record.dateText == "Aug 06 2026")
    }

    @Test func dateTextFallsBackToTheRawValueWhenUnparsable() {
        let record = AttendanceDataModel.UserAttendanceDetail(
            attendanceDate: "06/08/2026", attendanceStatus: "Attended",
            withdrewReason: nil, withdrewRemark: nil
        )

        #expect(record.dateText == "06/08/2026")
    }

    @Test(arguments: [nil, "", "   "] as [String?])
    func dateTextShowsAPlaceholderForMissingValues(raw: String?) {
        let record = AttendanceDataModel.UserAttendanceDetail(
            attendanceDate: raw, attendanceStatus: "Attended",
            withdrewReason: nil, withdrewRemark: nil
        )

        #expect(record.dateText == "-")
    }

    @Test(arguments: [nil, "", "   "] as [String?])
    func statusTextShowsAPlaceholderForMissingValues(raw: String?) {
        let record = AttendanceDataModel.UserAttendanceDetail(
            attendanceDate: "2026-08-06T12:00:00", attendanceStatus: raw,
            withdrewReason: nil, withdrewRemark: nil
        )

        #expect(record.statusText == "-")
    }

    /// A date-only value has no time component; `parseAPIDate`'s second format handles it.
    @Test func dateTextHandlesADateOnlyValue() {
        let record = AttendanceDataModel.UserAttendanceDetail(
            attendanceDate: "2026-08-06", attendanceStatus: "Attended",
            withdrewReason: nil, withdrewRemark: nil
        )

        #expect(record.dateText == "Aug 06 2026")
    }
}
