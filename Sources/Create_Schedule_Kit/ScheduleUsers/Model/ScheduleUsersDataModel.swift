//
//  ScheduleUsersDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the two user lists reachable from Schedule Details: the waiting
//  list and the availability roster. Both render the same row from the same body; only the
//  route, the response envelope and the copy differ — see `Mode`.
//

import Foundation
import NetworkService

enum ScheduleUsersDataModel {

    // MARK: - Mode

    /// Which list a screen is showing. Pure, so the copy and the routing are testable
    /// without standing up a view.
    enum Mode: String, CaseIterable, Equatable {
        case waiting
        case availability

        var title: String {
            switch self {
            case .waiting:      return "Waiting List"
            case .availability: return "Users Availability"
            }
        }

        var sectionTitle: String {
            switch self {
            case .waiting:      return "WAITING"
            case .availability: return "USERS"
            }
        }

        var emptyMessage: String {
            switch self {
            case .waiting:      return "No one is on the waiting list"
            case .availability: return "No users found"
            }
        }

        var emptyIcon: String {
            switch self {
            case .waiting:      return "hourglass"
            case .availability: return "person.2"
            }
        }

        /// The body's `Type`. Both lists send `null`; the nominee list on Schedule Details
        /// posts the same attendance route with `"Attandance"` and gets a narrower set.
        var apiType: String? { nil }

        /// The waiting envelope reports its own `totalRecords`; the availability route
        /// answers with a bare array, so its total needs a second call.
        var needsSeparateCountCall: Bool {
            switch self {
            case .waiting:      return false
            case .availability: return true
            }
        }
    }

    // MARK: - Endpoints

    /// POST — users waiting for a place. Returns `{totalRecords, waitingdata}`.
    struct GetUsersForWaitingRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersForWaiting]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — the availability roster. Returns a bare `[ScheduleUser]`.
    struct GetUsersForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — how many users the availability roster holds. Returns a bare `Int`.
    struct GetUsersCountForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersCountForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payload

    /// Shared body for all three routes.
    ///
    /// The nullable filter keys are encoded as explicit JSON `null` rather than omitted,
    /// matching the web client's body — the same reason `NominateUserCountPayload` writes
    /// its own `encode(to:)`.
    struct UsersPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let page: Int
        let pageSize: Int
        /// Names the column `searchText` filters on. Sent together with it, or not at all.
        let search: String?
        let searchText: String?
        let search1: String?
        let searchText1: String?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId, page, pageSize
            case search, searchText, search1, searchText1
            case type = "Type"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(scheduleID, forKey: .scheduleID)
            try c.encode(courseId, forKey: .courseId)
            try c.encode(moduleId, forKey: .moduleId)
            try c.encode(page, forKey: .page)
            try c.encode(pageSize, forKey: .pageSize)
            try c.encodeOrNull(search, forKey: .search)
            try c.encodeOrNull(searchText, forKey: .searchText)
            try c.encodeOrNull(search1, forKey: .search1)
            try c.encodeOrNull(searchText1, forKey: .searchText1)
            try c.encodeOrNull(type, forKey: .type)
        }
    }

    // MARK: - Domain model

    /// One row of either list. The response carries several keys this does not declare
    /// (`referenceRequestID`, `noticePeriod`, `config9`, `division`, `userprofile`) —
    /// decoding tolerates them.
    struct ScheduleUser: Decodable, Identifiable, Equatable {
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

        /// "Confirmed" once the nomination is accepted, otherwise whatever the server calls
        /// the request's state — "Pending" when it says nothing at all.
        var statusText: String {
            if isConfirmed { return "Confirmed" }
            return trainingRequestStatus ?? "Pending"
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

    /// `GetUsersForWaiting` wraps its rows and reports the total itself.
    struct WaitingResponse: Decodable {
        let totalRecords: Int?
        let waitingdata: [ScheduleUser]?

        var users: [ScheduleUser] { waitingdata ?? [] }
    }
}

private extension KeyedEncodingContainer {
    /// Writes the value, or an explicit `null` when it is absent.
    mutating func encodeOrNull<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
