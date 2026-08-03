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
//   • ILTTrainingAttendance/UpdateILTTrainingAttendance  → NominateUsersDataModel.NominateResponse (save)
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

    /// POST — save/mark attendance. Body is a JSON array of `UpdateItem`.
    /// Returns the shared `NominateUsersDataModel.NominateResponse` envelope.
    struct UpdateAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.updateILTTrainingAttendance]
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

    /// One element of the `UpdateILTTrainingAttendance` array body.
    /// CodingKeys mirror the exact (mixed-case) keys the API expects — `IsPresent` is
    /// capitalized while the rest are camelCase, and `scheduleId` is lowercase-d.
    struct UpdateItem: Encodable {
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
}
