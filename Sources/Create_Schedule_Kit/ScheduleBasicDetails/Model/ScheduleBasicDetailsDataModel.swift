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
    struct Credential: Codable, DropDownMenuProtocolPkg {
        let id: Int?
        let teamsEmail: String?
        let username: String?
        let password: String?
        let isDefault: Int?

        var description: String {
            if let username, !username.isEmpty { return username }
            return isDefault == 1 ? "Default account" : "My account"
        }
    }
}

// MARK: - Credential decoding
//
// The credential endpoints are one-per-provider (`GetTeamsCred` / `GetZoomCred` /
// `GetGsuitCred`) and each response spells the account field with its own provider
// prefix, so a fixed `teamsEmail` key only ever matched the Teams payload — the others
// decoded to nil and the card rendered "—" with nothing for the eye button to reveal.
// Decode against a dynamic key container instead: take the first known spelling, then
// fall back to any key that reads as an email field.
extension ScheduleBasicDetailsDataModel.Credential {

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// Known spellings first (cheapest and unambiguous), then a suffix scan so a new
    /// provider's `<provider>Email` key works without another code change.
    private static let emailKeys = [
        "teamsEmail", "zoomEmail", "gsuitEmail", "gsuiteEmail",
        "emailId", "emailID", "userEmail", "accountEmail", "email"
    ]

    private static func string(
        _ container: KeyedDecodingContainer<AnyKey>,
        candidates: [String],
        suffix: String? = nil
    ) -> String? {
        let keys = container.allKeys
        for candidate in candidates {
            guard let key = keys.first(where: { $0.stringValue.caseInsensitiveCompare(candidate) == .orderedSame } ),
                  let value = try? container.decode(String.self, forKey: key),
                  !value.isEmpty
            else { continue }
            return value
        }
        guard let suffix else { return nil }
        for key in keys where key.stringValue.lowercased().hasSuffix(suffix) {
            guard let value = try? container.decode(String.self, forKey: key), !value.isEmpty else { continue }
            return value
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        teamsEmail = Self.string(container, candidates: Self.emailKeys, suffix: "email")
        username = Self.string(container, candidates: ["username", "userName", "user_name", "loginId", "loginID"])
        password = Self.string(container, candidates: ["password", "pwd", "teamsPassword", "zoomPassword", "gsuitPassword"])

        let idKey = container.allKeys.first { $0.stringValue.caseInsensitiveCompare("id") == .orderedSame }
        id = idKey.flatMap { key in
            (try? container.decode(Int.self, forKey: key))
                ?? (try? container.decode(String.self, forKey: key)).flatMap(Int.init)
        }

        let defaultKey = container.allKeys.first { $0.stringValue.caseInsensitiveCompare("isDefault") == .orderedSame }
        isDefault = defaultKey.flatMap { key in
            (try? container.decode(Int.self, forKey: key))
                ?? (try? container.decode(Bool.self, forKey: key)).map { $0 ? 1 : 0 }
        }
    }
}
