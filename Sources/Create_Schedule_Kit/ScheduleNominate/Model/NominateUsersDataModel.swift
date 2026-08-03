//
//  NominateUsersDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the post-create "Nominate Users" flow.
//
//  Sequence (see NominateUsersViewModel.start()):
//   1. IsBatchwiseNominationEnabled                 → "No"/"Yes"
//   2. Module/GetModulesILTByCourse/{courseID}      → reuses ScheduleBasicDetailsDataModel
//                                                      (.ModulesByCourseRequest / .ModuleItem)
//   3. TrainingNomination/GetByModuleId/{mod}/{crs} → [ModuleSchedule] → scheduleID = first.id
//   4. TrainingNomination/GetUsersCountForNomination → Int (total user count)
//   5. TrainingNomination/GetUsersForNominationV2    → encrypted String → [NominationUser]
//   6. User/Setting/GetColumnsForAccessibilty        → [AccessibilityColumn] (search columns)
//   7. User/GetTypeAhead                             → [TypeAheadResult] (search suggestions)
//   8. TrainingNomination/NominateUser/…             → NominateResponse (submit)
//

import Foundation
import NetworkService
import SwiftUIUtilities

enum NominateUsersDataModel {

    // MARK: - Endpoints

    /// GET — returns a bare JSON string, e.g. "No" / "Yes".
    struct IsBatchwiseNominationEnabledRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iSegment, APIConst.iltBatch, APIConst.isBatchwiseNominationEnabled]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET — schedules for a module+course. Returns `[ModuleSchedule]`.
    struct GetByModuleIdRequest: EndpointModel {
        let moduleId: Int
        let courseId: Int
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.getByModuleId,
             "\(moduleId)", "\(courseId)"].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST — total nominatable user count. Returns a bare `Int`.
    struct GetUsersCountRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.getUsersCountForNomination]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — paginated nominatable users. Returns an encrypted `String` (decrypt → `[NominationUser]`).
    struct GetUsersForNominationRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.getUsersForNominationV2]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// GET — configurable search columns used by the "Select" dropdown.
    struct GetColumnsRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.user, APIConst.setting, APIConst.getColumnsForAccessibilty]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST — search typeahead. Both payload fields are AES-encrypted in-package.
    /// Returns `[TypeAheadResult]`.
    struct GetTypeAheadRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.user, APIConst.getTypeAhead].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — submit nominations. Body is a JSON array of `NominateItem`. Returns `NominateResponse`.
    struct NominateUserRequest: EndpointModel {
        let scheduleID: Int
        let moduleId: Int
        let courseId: Int
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.nominateUser,
             "\(scheduleID)", "\(moduleId)", "\(courseId)", "0"].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payloads

    /// Shared body for `GetUsersCount` (step 4) and `GetUsersForNomination` (step 5).
    struct UsersPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let page: Int
        let pageSize: Int
        let search: String?       // selected column's `configuredColumnName`, else nil
        let searchText: String?   // search-bar text, else nil
        let type: String          // always "Nominate"

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId, page, pageSize, search, searchText
            case type = "Type"
        }
    }

    /// Body for `GetTypeAhead` (step 7). Both values are encrypted before sending.
    struct TypeAheadPayload: Encodable {
        let searchByColumn: String
        let searchText: String
    }

    /// One entry of the `NominateUser` (step 8) array body.
    struct NominateItem: Encodable {
        let userId: Int
        let userName: String
        let emailId: String
        let mobileNumber: String
    }

    // MARK: - Response / Domain models

    /// Step 3 — maps a module+course to its schedule(s).
    struct ModuleSchedule: Decodable {
        let id: Int
        let scheduleCode: String?
    }

    /// Step 5 — a nominatable user (decoded from the decrypted JSON array).
    /// The decrypted payload uses PascalCase keys (`ID`, `UserId`, …), and
    /// `decryptAndDecodeNew` decodes with a plain `JSONDecoder` (no key strategy),
    /// so the mapping must be spelled out explicitly.
    struct NominationUser: Decodable, Identifiable, Equatable {
        let id: Int
        let userId: String?
        let userName: String?
        let emailId: String?
        let mobileNumber: String?
        let status: String?

        var displayName: String { userName ?? userId ?? "User \(id)" }

        enum CodingKeys: String, CodingKey {
            case id = "ID"
            case userId = "UserId"
            case userName = "UserName"
            case emailId = "EmailId"
            case mobileNumber = "MobileNumber"
            case status = "Status"
        }
    }

    /// Step 6 — a search column for the "Select" dropdown.
    struct AccessibilityColumn: Codable, Identifiable, DropDownMenuProtocolPkg {
        let columnId: Int
        let configuredColumnName: String
        let changedColumnName: String

        var id: String { configuredColumnName }
        var description: String { changedColumnName }

        enum CodingKeys: String, CodingKey {
            case columnId = "id"
            case configuredColumnName
            case changedColumnName
        }
    }

    /// Step 7 — a search suggestion. Conforms to `DropDownMenuProtocolPkg` so it can
    /// back the searchable search dropdown.
    struct TypeAheadResult: Decodable, DropDownMenuProtocolPkg {
        let id: Int
        let name: String?

        var description: String { name ?? "" }
    }

    /// Step 8 — submit response envelope.
    struct NominateResponse: Decodable {
        let statusCode: Int?
        let message: String?
        let description: String?
        let aPINominationResponses: [NominationResult]?
    }

    struct NominationResult: Decodable {
        let userId: String?
        let userName: String?
        let status: String?
        let errorMessage: String?
    }
}
