//
//  ScheduleBasicDetailsDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs + domain types for Step 1 (Basic Details).
//  Encrypted server fields (e.g. credential emails) are kept as opaque Strings.
//

import Foundation
import NetworkService
import SwiftUIUtilities

struct ScheduleBasicDetailsDataModel {

    // MARK: - Endpoints

    /// GET schedule code — returns a bare JSON string e.g. "SC6477".
    struct ScheduleCodeRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.scheduleCode].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET course typeahead.
    struct CourseTypeAheadRequest: EndpointModel {
        let query: String
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.getRoleCourseNameTypeAhead, query]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET ILT modules for a given course code.
    struct ModulesByCourseRequest: EndpointModel {
        let courseID: String
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.module, APIConst.getModulesILTByCourse, courseID]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET timezones (static asset on the same host).
    struct TimezonesRequest: EndpointModel {
        var path: String { APIConst.timezonesJsonPath }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET stored webinar credentials. Path differs per provider.
    struct CredentialRequest: EndpointModel {
        let endpointName: String   // "GetZoomCred" / "GetTeamsCred" / "GetGsuitCred"
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.user, endpointName].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    // MARK: - Domain / DTO types

    struct Course: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: Int
        let title: String
        let code: String

        var description: String { title }
    }

    struct ModuleItem: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: Int
        let title: String
        let type: String?
        let courseFee: Double?
        let currency: String?
        let category: String?
        let subCategory: String?
        let subSubCategory: String?

        var description: String { title }
    }

    struct TimezoneItem: Codable, Identifiable, DropDownMenuProtocolPkg {
        let value: String
        let code: String
        let offset: Double
        let isdst: Bool
        let name: String

        var id: String { value }
        var description: String { name }
    }

    /// Stored credential. `teamsEmail` / `password` may be AES-encrypted opaque strings.
    struct Credential: Codable {
        let id: Int?
        let teamsEmail: String?
        let username: String?
        let password: String?
        let isDefault: Int?
    }
}
