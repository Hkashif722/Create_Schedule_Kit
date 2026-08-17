//
//  ScheduleDetailDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the Schedule Details screen's nominees section.
//
//   • ILTTrainingAttendance/GetUsersForAttendance      → [Nominee]  (paginated)
//   • ILTTrainingAttendance/GetUsersCountForAttendance → Int        (count, parallel)
//   • TrainingNomination/DeleteUserNomination          → empty body (remove a nominee)
//

import Foundation
import NetworkService

enum ScheduleDetailDataModel {

    // MARK: - Endpoints

    /// POST — nominated/attending users for a schedule. Returns a bare `[Nominee]`.
    struct GetUsersForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — count of nominees for a schedule. Returns a bare `Int`.
    struct GetUsersCountForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersCountForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — remove a nominated user from the schedule. Returns an empty body.
    struct DeleteUserNominationRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.deleteUserNomination]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payload

    /// Body for `DeleteUserNomination`. `UserIdEncrypted` is the encrypted user id from the
    /// nominee row — passed through untouched, never decoded.
    struct DeleteNominationPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let userIdEncrypted: String

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId
            case userIdEncrypted = "UserIdEncrypted"
        }
    }

    /// Shared body for the attendance list + count. `Type` keeps the server's "Attandance" spelling.
    struct AttendancePayload: Encodable {
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

    // MARK: - Domain model

    struct Nominee: Decodable, Identifiable, Equatable {
        let id: Int
        let userId: String?
        let userName: String?
        let emailId: String?
        let mobileNumber: String?
        let status: String?
        let trainingRequestStatus: String?
        let overAllStatus: String?
        let isPresent: Bool?

        var displayName: String { userName ?? userId ?? "User \(id)" }
        var isConfirmed: Bool { (status ?? "").lowercased() == "true" }
        var statusText: String {
            if isConfirmed { return "Confirmed" }
            return trainingRequestStatus ?? "Pending"
        }
    }
}
