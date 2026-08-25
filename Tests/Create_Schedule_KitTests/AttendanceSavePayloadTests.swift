//
//  AttendanceSavePayloadTests.swift
//  Create_Schedule_KitTests
//
//  Pins the Attendance screen's Save payload to the web client's, field for field.
//
//  Save and the Nominate tab post to the same `ILTTrainingAttendance` route with different
//  body shapes. Sending the Nominate shape from Save made the server answer
//  400 "Attendance for the user already exists." — the `Z`-suffixed date was read as UTC and
//  shifted to server-local time, so it no longer matched the user's already-marked row.
//  These tests exist so that shape cannot drift back.
//
//  `IsPresent` is derived from the status code via `AttendanceDataModel.isPresent(forStatusCode:)`
//  — true for Attended and Absent — which agrees with the web sample below.
//

import Testing
import Foundation
import NetworkService
@testable import Create_Schedule_Kit

@Suite struct AttendanceSavePayloadTests {

    // MARK: - Helpers

    /// The exact body the web client sends when marking attendance, captured from its
    /// network log. Every assertion below is derived from this sample.
    private let webSample = """
    {
        "id": 0,
        "IsPresent": true,
        "userId": 11998,
        "moduleId": 46399,
        "scheduleId": 4122,
        "courseId": 59245,
        "attendanceStatus": "NOSHOWNCOSTAPPL",
        "isweb": true,
        "attendanceDate": "2026-08-19T00:00:00",
        "withdrewReason": null,
        "withdrewRemark": null
    }
    """

    private func markItem(
        statusCode: String = "NOSHOWNCOSTAPPL",
        attendanceDate: String = "2026-08-19T00:00:00"
    ) -> AttendanceDataModel.MarkAttendanceItem {
        .init(
            id: 0,
            isPresent: AttendanceDataModel.isPresent(forStatusCode: statusCode),
            userId: 11998,
            moduleId: 46399,
            scheduleId: 4122,
            courseId: 59245,
            isweb: true,
            attendanceStatus: statusCode,
            attendanceDate: attendanceDate,
            withdrewReason: nil,
            withdrewRemark: nil
        )
    }

    private func encodeToObject<T: Encodable>(_ payload: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return object as? [String: Any] ?? [:]
    }

    // MARK: - Parity with the web payload

    /// The whole point: Save's body must carry the same keys and values as web's.
    @Test func saveBodyMatchesTheWebClientPayload() throws {
        let mine = try encodeToObject(markItem())
        let webData = try #require(webSample.data(using: .utf8))
        let theirs = try #require(
            JSONSerialization.jsonObject(with: webData) as? [String: Any]
        )

        #expect(Set(mine.keys) == Set(theirs.keys))
        #expect(mine["attendanceDate"] as? String == theirs["attendanceDate"] as? String)
        #expect(mine["IsPresent"] as? Bool == theirs["IsPresent"] as? Bool)
        #expect(mine["attendanceStatus"] as? String == theirs["attendanceStatus"] as? String)
        #expect(mine["userId"] as? Int == theirs["userId"] as? Int)
        #expect(mine["scheduleId"] as? Int == theirs["scheduleId"] as? Int)
        #expect(mine["isweb"] as? Bool == theirs["isweb"] as? Bool)
        #expect(mine["id"] as? Int == theirs["id"] as? Int)
    }

    // MARK: - The fields that caused the 400

    /// `AttendanceDate` (PascalCase, `InsertItem`'s spelling) must not appear — Save spells it
    /// camelCase exactly as web does.
    @Test func dateKeyIsCamelCasedUnlikeTheNominateInsertBody() throws {
        let object = try encodeToObject(markItem())

        #expect(object.keys.contains("attendanceDate"))
        #expect(object["AttendanceDate"] == nil)
    }

    /// The regression that produced "Attendance for the user already exists.": a trailing `Z`
    /// marks the value UTC, so .NET shifts it to server-local time on parse.
    @Test func dateCarriesNoTimezoneMarkerOrMilliseconds() throws {
        let raw = try #require(String(data: try JSONEncoder().encode(markItem()), encoding: .utf8))

        #expect(raw.contains("\"attendanceDate\":\"2026-08-19T00:00:00\""))
        #expect(!raw.contains("Z\""))
        #expect(!raw.contains(".000"))
    }

    /// Web sends nulls here; `InsertItem` sends empty strings. JSONSerialization cannot tell an
    /// absent key from a null, so the raw JSON is checked too.
    @Test func withdrewFieldsAreNullNotEmptyStrings() throws {
        let raw = try #require(String(data: try JSONEncoder().encode(markItem()), encoding: .utf8))

        #expect(raw.contains("\"withdrewReason\":null"))
        #expect(raw.contains("\"withdrewRemark\":null"))
        #expect(!raw.contains("\"withdrewReason\":\"\""))
    }

    /// `IsPresent` is true for the two real attendance outcomes and false for the two
    /// administrative exclusions. These four codes are the full ATTDSTATUS set.
    @Test(arguments: [
        ("ATTD", true),              // Attended
        ("NOSHOWNCOSTAPPL", true),   // Absent
        ("WDLNCOSTAPPL", false),     // Withdrew
        ("WAIVER", false)            // Waived
    ])
    func isPresentIsTrueForAttendedAndAbsent(code: String, expected: Bool) throws {
        let object = try encodeToObject(markItem(statusCode: code))

        #expect(object["IsPresent"] as? Bool == expected)
        #expect(object["attendanceStatus"] as? String == code)
    }

    /// An unrecognised code must still encode rather than trap — the status list is
    /// server-driven, so a newly configured value can appear at any time.
    @Test func isPresentFallsBackToFalseForAnUnknownCode() throws {
        let object = try encodeToObject(markItem(statusCode: "SOMETHING_NEW"))

        #expect(object["IsPresent"] as? Bool == false)
        #expect(object["attendanceStatus"] as? String == "SOMETHING_NEW")
    }

    /// The key stays PascalCase — a camelCase `isPresent` would be a silent rename.
    @Test func isPresentKeyIsPascalCased() throws {
        let object = try encodeToObject(markItem())

        #expect(object.keys.contains("IsPresent"))
        #expect(object["isPresent"] == nil)
    }

    // MARK: - Date formatting

    /// `selectedDate` may carry a wall-clock time; the payload must still pin to the day start
    /// the server matches on.
    @Test func isoDayStartStringPinsToMidnightWithoutAZone() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 19
        components.hour = 14
        components.minute = 32
        components.second = 11
        let afternoon = try #require(Calendar.current.date(from: components))

        #expect(afternoon.isoDayStartString == "2026-08-19T00:00:00")
    }

    /// The two formats are deliberately different — this is the distinction the bug turned on.
    @Test func dayStartFormatsDifferFromTheNominateInsertFormat() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 19
        let day = try #require(Calendar.current.date(from: components))

        #expect(day.isoDayStartString == "2026-08-19T00:00:00")
        #expect(day.isoDayStartUTCString == "2026-08-19T00:00:00.000Z")
        #expect(day.isoDayStartString != day.isoDayStartUTCString)
    }

    // MARK: - Route

    /// Save posts to the same bare controller path the web client uses.
    @Test func saveUsesTheBareAttendanceRoute() {
        let request = AttendanceDataModel.InsertAttendanceRequest()

        #expect(request.path == "/api/v1/ILTTrainingAttendance")
        #expect(request.method == .post)
    }

    /// The body is sent as a JSON array, not a bare object.
    @Test func saveBodyEncodesAsAnArray() throws {
        let data = try JSONEncoder().encode([markItem(), markItem()])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        #expect(array?.count == 2)
        #expect(array?.first?["userId"] as? Int == 11998)
    }
}
