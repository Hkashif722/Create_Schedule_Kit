//
//  AttendanceDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the "Update Attendance" screen (launched from a schedule card).
//
//   • ILTTrainingAttendance/GetUsersForAttendance        → [AttendanceUser]  (paginated)
//   • ILTTrainingAttendance/GetUsersCountForAttendance   → Int               (total, parallel)
//   • ConfigurableValues/ATTDSTATUS                      → [AttendanceStatusOption]
//   • user/GetConfigurableParameterValue/AttendanceOnCurrentDate → String ("Yes"/"No")
//   • ConfigurableParameters/GetValue/ATTNOM_DEL         → reuses ScheduleListDataModel.ConfigValueResponse
//   • ILTTrainingAttendance                              → NominateUsersDataModel.NominateResponse
//       body: MarkAttendanceItem (Save) | InsertItem (Nominate tab) — see those types
//   • ILTTrainingAttendance/AttendanceDelete             → Bool              (remove a user)
//   • ILTTrainingAttendance/GetDetailsForUserAttendance  → [UserAttendanceDetail] (row's eye button)
//

import Foundation
import NetworkService
import SwiftUIUtilities

enum AttendanceDataModel {

    // MARK: - Endpoints

    /// POST — paginated attendance user list. Returns `[AttendanceUser]`.
    struct GetUsersForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — total attendance user count. Returns a bare `Int`.
    struct GetUsersCountForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersCountForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// GET — attendance status dropdown options. Returns `[AttendanceStatusOption]`.
    struct GetAttendanceStatusRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.configurableValues, APIConst.attdStatus]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET — "Yes"/"No": whether attendance may only be marked on the current date.
    struct GetAttendanceOnCurrentDateRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.userLower,
             APIConst.getConfigurableParameterValue, APIConst.attendanceOnCurrentDate]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST — remove a user's attendance record. Returns a bare `Bool`.
    struct AttendanceDeleteRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.attendanceDelete]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — one user's attendance history for a schedule. Returns `[UserAttendanceDetail]`.
    /// Backs the eye button on each attendance row.
    struct GetDetailsForUserAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI,
             APIConst.iltTrainingAttendance, APIConst.getDetailsForUserAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — insert attendance rows directly against the bare `ILTTrainingAttendance` path,
    /// the single attendance-write route. Two callers share it: the Attendance screen's Save,
    /// and the Nominate tab embedded in that screen (a back-dated schedule cannot be nominated
    /// for, so the selected users are written straight into attendance instead).
    struct InsertAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payloads

    /// Shared body for `GetUsersForAttendance` + `GetUsersCountForAttendance`.
    /// NOTE: `type` is sent as `"Attandance"` — the API's real (mis-spelled) value.
    struct UsersPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let page: Int
        let pageSize: Int
        let searchText: String?
        let search1: String?
        let searchText1: String?
        let type: String

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId, page, pageSize, searchText, search1, searchText1
            case type = "Type"
        }
    }

    /// Body for `AttendanceDelete`. Keys are PascalCase exactly as the server expects.
    struct AttendanceDeletePayload: Encodable {
        let userMasterId: Int
        let scheduleId: Int

        enum CodingKeys: String, CodingKey {
            case userMasterId = "UserMasterId"
            case scheduleId = "ScheduleId"
        }
    }

    /// Body for `GetDetailsForUserAttendance`. Keys are plain camelCase — `scheduleID` keeps
    /// the capital `D` exactly as `UsersPayload` spells it. `userId` here is the row's numeric
    /// master id (`AttendanceUser.id`), *not* the login-name `AttendanceUser.userId` string.
    struct UserAttendanceDetailPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let userId: Int
    }

    // MARK: - Attendance status codes

    /// The `ATTDSTATUS` configurable values, as served by `ConfigurableValues/ATTDSTATUS`.
    /// Raw strings rather than an enum because the list is server-driven — these are the four
    /// codes currently configured, and an unrecognised code must still round-trip.
    enum StatusCode {
        static let attended = "ATTD"
        static let withdrew = "WDLNCOSTAPPL"
        static let absent   = "NOSHOWNCOSTAPPL"
        static let waived   = "WAIVER"
    }

    /// The `IsPresent` flag that accompanies a status code in the save payload.
    ///
    /// | Code              | Name     | IsPresent |
    /// |-------------------|----------|-----------|
    /// | `ATTD`            | Attended | `true`    |
    /// | `NOSHOWNCOSTAPPL` | Absent   | `true`    |
    /// | `WDLNCOSTAPPL`    | Withdrew | `false`   |
    /// | `WAIVER`          | Waived   | `false`   |
    ///
    /// Attended and Absent are both real attendance outcomes for someone who was expected at
    /// the session, so the flag is set; Withdrew and Waived are administrative exclusions.
    /// This matches the web client, which sends `IsPresent: true` for Absent. Anything not in
    /// the table falls to `false`.
    static func isPresent(forStatusCode code: String) -> Bool {
        switch code {
        case StatusCode.attended, StatusCode.absent: return true
        default: return false
        }
    }

    /// One element of the `ILTTrainingAttendance` array body **as sent by the Attendance
    /// screen's Save** — a byte-for-byte match for the web client's save payload.
    ///
    /// Same endpoint as `InsertItem` but a different body shape, which is why the two are
    /// kept apart: `attendanceDate` is camelCase and zone-less (`2026-08-19T00:00:00`), and
    /// the `withdrew*` fields are null rather than empty strings. Sending `InsertItem`'s
    /// `AttendanceDate: "...000Z"` here makes the server shift the value to its own local
    /// time, miss the already-marked row, and reject the save as a duplicate with
    /// "Attendance for the user already exists."
    struct MarkAttendanceItem: Encodable {
        let id: Int
        let isPresent: Bool
        let userId: Int
        let moduleId: Int
        let scheduleId: Int
        let courseId: Int
        let isweb: Bool
        let attendanceStatus: String
        let attendanceDate: String
        let withdrewReason: String?
        let withdrewRemark: String?

        enum CodingKeys: String, CodingKey {
            case id
            case isPresent = "IsPresent"
            case userId, moduleId, scheduleId, courseId, isweb
            case attendanceStatus, attendanceDate, withdrewReason, withdrewRemark
        }

        /// Hand-rolled so the `withdrew*` keys are always present. The synthesized encoding
        /// uses `encodeIfPresent` for optionals, which drops a nil key entirely — web sends
        /// an explicit `null`, so omitting them would reintroduce a divergence.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(isPresent, forKey: .isPresent)
            try container.encode(userId, forKey: .userId)
            try container.encode(moduleId, forKey: .moduleId)
            try container.encode(scheduleId, forKey: .scheduleId)
            try container.encode(courseId, forKey: .courseId)
            try container.encode(isweb, forKey: .isweb)
            try container.encode(attendanceStatus, forKey: .attendanceStatus)
            try container.encode(attendanceDate, forKey: .attendanceDate)
            try Self.encodeOrNull(withdrewReason, forKey: .withdrewReason, in: &container)
            try Self.encodeOrNull(withdrewRemark, forKey: .withdrewRemark, in: &container)
        }

        private static func encodeOrNull(
            _ value: String?,
            forKey key: CodingKeys,
            in container: inout KeyedEncodingContainer<CodingKeys>
        ) throws {
            if let value {
                try container.encode(value, forKey: key)
            } else {
                try container.encodeNil(forKey: key)
            }
        }
    }

    /// One element of the bare `ILTTrainingAttendance` array body. Casing mirrors the
    /// server sample exactly — `IsPresent` and `AttendanceDate` are PascalCase while the
    /// rest stay camelCase — and the `withdrew*` fields are empty strings, not null.
    struct InsertItem: Encodable {
        let id: Int
        let isPresent: Bool
        let userId: Int
        let moduleId: Int
        let scheduleId: Int
        let courseId: Int
        let isweb: Bool
        let attendanceStatus: String
        let attendanceDate: String
        let withdrewReason: String
        let withdrewRemark: String

        enum CodingKeys: String, CodingKey {
            case id
            case isPresent = "IsPresent"
            case userId, moduleId, scheduleId, courseId, isweb
            case attendanceStatus
            case attendanceDate = "AttendanceDate"
            case withdrewReason, withdrewRemark
        }
    }

    // MARK: - Domain models

    /// One attendance row. Keys match the JSON exactly (plain camelCase), so no key strategy needed.
    struct AttendanceUser: Decodable, Identifiable, Equatable {
        let id: Int
        let scheduleID: Int?
        let userId: String?
        let userName: String?
        let emailId: String?
        let mobileNumber: String?
        let isPresent: Bool?
        let moduleID: Int?
        let courseID: Int?
        let overAllStatus: String?
        let attendanceStatus: String?
        let attendanceDate: String?

        var displayName: String { userName ?? userId ?? "User \(id)" }

        /// `true` when the row carries an overall status. Attendance may only be deleted for
        /// such rows — see `AttendanceViewModel.didTapDeleteUser`.
        var hasOverAllStatus: Bool {
            guard let raw = overAllStatus?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !raw.isEmpty
        }

        var initials: String {
            let parts = displayName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first.map(String.init) }
            let joined = parts.joined().uppercased()
            return joined.isEmpty ? "?" : joined
        }
    }

    /// A single "Attendance Status" dropdown option (e.g. Attended / Withdrew / Absent).
    /// Backs `DropDownMenuListViewPkg` via `DropDownMenuProtocolPkg`.
    struct AttendanceStatusOption: Decodable, Identifiable, DropDownMenuProtocolPkg {
        let valueCode: String
        let valueName: String
        let sequence: Int?
        let isDeleted: Bool?

        var id: String { valueCode }
        var description: String { valueName }
    }

    /// One row of the "User Attendance Details" popup. Unlike `AttendanceUser.attendanceStatus`,
    /// this arrives as the display name (`"Attended"`) rather than the `ATTD` code, so it needs
    /// no `AttendanceStatusOption` lookup.
    ///
    /// Deliberately not `Identifiable`: the response carries no id and a user can hold two
    /// records with the same date and status, so the view iterates by offset.
    /// `withdrewReason` / `withdrewRemark` are part of the response contract but aren't
    /// displayed — the web table has only the two columns.
    struct UserAttendanceDetail: Decodable {
        let attendanceDate: String?
        let attendanceStatus: String?
        let withdrewReason: String?
        let withdrewRemark: String?

        /// `Aug 06 2026`, matching the web modal. An unparsable value falls back to the raw
        /// string so a server format change degrades rather than blanking the row.
        var dateText: String {
            guard let raw = attendanceDate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return "-" }
            guard let date = ScheduleDraft.parseAPIDate(raw) else { return raw }
            return date.formatted(using: "MMM dd yyyy")
        }

        var statusText: String {
            let raw = attendanceStatus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return raw.isEmpty ? "-" : raw
        }
    }
}
