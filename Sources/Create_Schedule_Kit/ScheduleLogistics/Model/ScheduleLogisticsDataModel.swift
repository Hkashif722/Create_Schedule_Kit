//
//  ScheduleLogisticsDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs + domain types for Step 2 (Logistics).
//  Trainer fields (emailId / userId / mobileNumber / id) are encrypted opaque Strings.
//

import Foundation
import NetworkService
import SwiftUIUtilities

struct ScheduleLogisticsDataModel {

    // MARK: - Endpoints

    /// GET academy typeahead (Internal scope).
    struct AcademyTypeAheadRequest: EndpointModel {
        let query: String
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.getAcademyTypeAhead, APIConst.internalSegment, query]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET training place typeahead.
    struct TrainingPlaceTypeAheadRequest: EndpointModel {
        let query: String
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingPlace, APIConst.trainingPlaceTypeAhead, query]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET full training-place detail by id (carries contactPerson / contactNumber).
    struct TrainingPlaceDetailRequest: EndpointModel {
        let id: Int
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingPlace, "\(id)"].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST trainer search (server-side typeahead). `userId` carries the search keyword and
    /// `userType` the selected trainer type; both are encrypted in-package before sending.
    struct SearchTrainerRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.userLower, APIConst.searchTrainer].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }

        struct Payload: Encodable {
            let userId: String
            let userType: String
        }
    }

    /// POST user search for the coordinator type-ahead (edit mode). Same contract as
    /// `SearchTrainerRequest`: `userId` carries the typed keyword and `userType` the
    /// user type; both are encrypted in-package before sending.
    struct SearchActiveInActiveUserRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.userLower, APIConst.searchActiveInActiveUser]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }

        struct Payload: Encodable {
            let userId: String
            let userType: String
        }
    }

    /// GET all tags.
    struct AllTagsRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.getAllTags].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    // MARK: - Domain / DTO types

    struct Academy: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: Int
        let title: String
        let type: String?

        var description: String { title }
    }

    struct TrainingPlace: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: Int
        let placeCode: String?
        let cityname: String?
        let placeName: String?
        let accommodationCapacity: String?
        let postalAddress: String?
        let contactNumber: String?
        let contactPerson: String?

        var description: String { placeName ?? cityname ?? "Place \(id)" }
    }

    struct Trainer: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: String           // encrypted
        let name: String
        let emailId: String?     // encrypted
        let userId: String?      // encrypted
        let profilePicture: String?
        let mobileNumber: String? // encrypted
        let userType: String?
        let nameUserId: String?

        var displayName: String { nameUserId ?? name }
        var description: String { displayName }

        /// "Chetan Wadil (Internal)" — the composed display the web client shows for a
        /// selected trainer. Falls back to the plain name when the type is unknown. The raw
        /// type is normalized through `TrainerType` so casing matches the web ("internal" →
        /// "Internal"); an unrecognized value passes through as-is.
        var displayNameWithType: String {
            let raw = (userType ?? "").trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return displayName }
            let title = TrainerType(rawValue: raw.lowercased())?.displayTitle ?? raw
            return "\(displayName) (\(title))"
        }

        /// Copy with the trainer type stamped in. The search endpoint does not reliably echo
        /// the type, but its results are already filtered by the wizard's selected Trainer
        /// Type — so selection stamps that value for display.
        func withUserType(_ type: String) -> Trainer {
            Trainer(
                id: id,
                name: name,
                emailId: emailId,
                userId: userId,
                profilePicture: profilePicture,
                mobileNumber: mobileNumber,
                userType: type,
                nameUserId: nameUserId
            )
        }
    }

    /// User row from `searchActiveInActiveUser`. Identity and contact fields are
    /// encrypted opaque strings; `mobileNumber` is decrypted in-package on selection.
    struct CoordinatorUser: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: String            // encrypted
        let dB_UserId: String?    // encrypted
        let name: String
        let emailId: String?      // encrypted
        let userId: String?       // encrypted
        let profilePicture: String?
        let mobileNumber: String? // encrypted
        let userType: String?
        let nameUserId: String?
        let isDeleted: Bool?
        let userMasterId: Int?

        var description: String { nameUserId ?? name }
    }

    struct Tag: Codable, Identifiable, DropDownMenuProtocolPkg {
        let id: Int
        let tag: String?
        let tagCode: String?
        let isActive: Bool?

        var description: String { tag ?? "" }
    }
}
