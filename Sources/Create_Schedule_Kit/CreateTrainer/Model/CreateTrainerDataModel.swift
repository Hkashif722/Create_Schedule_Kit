//
//  CreateTrainerDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for creating an external trainer on the fly from Step 2 (Logistics).
//
//  Two calls, in order:
//  1. `User/Exist` — mobile-number lookup, so an existing account is never duplicated.
//     Both payload fields are encrypted in-package.
//  2. `user` (lowercase route) — creates the account. The body mirrors the web client's
//     field-for-field, including the empty strings and explicit nulls it sends.
//
//  The create response returns identity fields already encrypted (`userId` / `emailId` /
//  `mobileNumber`); those are opaque strings and are passed through untouched. Only the
//  numeric `id` arrives in the clear, and it is encrypted here so the new trainer matches
//  the shape `searchTrainer` returns.
//

import Foundation
import NetworkService
import SwiftUIUtilities

struct CreateTrainerDataModel {

    // MARK: - Endpoints

    /// POST existence check. `searchByColumn` names the column ("mobile") and `searchText`
    /// carries the value; both are encrypted in-package before sending.
    struct UserExistRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.user, APIConst.exist]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }

        struct Payload: Encodable {
            let searchByColumn: String
            let searchText: String
        }

        /// Column name the lookup searches on, encrypted alongside the value.
        static let mobileColumn = "mobile"
    }

    /// POST create user. The lowercase `user` route — do not normalize.
    struct CreateUserRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.userLower]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Responses

    /// `{"statusCode":0,"message":"NotFound","description":"No record found!","result":null}`
    ///
    /// `result` is unmodelled — the package only needs to know whether a record came back,
    /// so it decodes shape-agnostically rather than pinning a schema that is only ever
    /// observed as `null`.
    struct UserExistResponse: Decodable {
        let statusCode: Int?
        let message: String?
        let description: String?
        let result: JSONValue?

        /// Anything other than an explicit not-found is treated as "this mobile is taken".
        /// Erring this way is deliberate: creating a duplicate account is the worse failure,
        /// and the user can still reach the same person through "Select User from System".
        var userExists: Bool {
            if let result, result != .null { return true }
            if message?.caseInsensitiveCompare(Self.notFoundMessage) == .orderedSame { return false }
            // No result and no not-found marker — statusCode 0 is the observed not-found code.
            return (statusCode ?? 0) != 0
        }

        static let notFoundMessage = "NotFound"
    }

    /// The created account. Only the fields the trainer chip and the schedule payload need
    /// are modelled; everything else the server echoes back is ignored.
    struct CreateUserResponse: Decodable {
        let id: Int?
        let userName: String?
        let emailId: String?      // encrypted
        let userId: String?       // encrypted
        let mobileNumber: String? // encrypted
        let userType: String?
        let userSubType: String?
    }

    // MARK: - Create payload

    /// Body for `POST user`. Field-for-field with the web client, including the empty strings
    /// and explicit nulls — the server rejects a trimmed-down body.
    struct CreateUserPayload: Encodable {

        // Values that vary per trainer.
        let userName: String
        let emailId: String
        let mobileNumber: String
        let customerCode: String
        let accountCreatedDate: String
        let accountExpiryDate: String
        let lastModifiedDate: String

        /// External trainers are always created with this role/type triple — it is what
        /// makes the account findable by `searchTrainer` under Trainer Type "External".
        static let userRole = "ET"
        static let userType = "External"
        static let userSubType = "externalTrainer"

        /// Org defaults the web client hardcodes on this form. The Create Trainer sheet
        /// collects name/email/mobile only, so these are not user-selectable here.
        static let timeZone = "(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi"
        static let currency = "Indian Rupee"
        static let language = "English"

        /// The account is created with a ten-year window, matching the web client.
        static let accountLifetimeYears = 10

        enum CodingKeys: String, CodingKey {
            case id, buddyTrainerId, mentorId, hrbpId
            case buddyTrainer, mentor, hrbp
            case customerCode, serialNumber
            case userId, userName, emailId, mobileNumber
            case userRole, userType, userSubType
            case gender, implicitRole
            case timeZone, currency, language
            case profilePicture, password
            case accountCreatedDate, accountExpiryDate, lastModifiedDate, lastModifiedDateNew
            case changedAttributes, oldData
            case reportsTo, business, group, area, location
            case dateOfBirth, dateIntoRole, dateOfJoining
            case configurationColumn1, configurationColumn2, configurationColumn3
            case configurationColumn4, configurationColumn5, configurationColumn6
            case configurationColumn7, configurationColumn8, configurationColumn9
            case configurationColumn10, configurationColumn11, configurationColumn12
            case configurationColumn13, configurationColumn14, configurationColumn15
            case configurationColumn16, configurationColumn17, configurationColumn18
            case configurationColumn19, configurationColumn20
            case isActive, isDeleted, isEnableDegreed, lock
            case termsCondintionsAccepted, acceptanceDate
            case house, ceoMessageHeading, ceoMessageDescription, ceoProfilePicture
            case isShowCEOMessageOnLandingPage, isShowCEOMessageAfterLogin
            case appearOnLeaderboard
            case jobRoleName, wallfeedRole, profabRole
            case federationId, country
            case vendorId, areaId, groupId, locationId, configurationColumn1Id
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(0, forKey: .id)
            try c.encodeNil(forKey: .buddyTrainerId)
            try c.encodeNil(forKey: .mentorId)
            try c.encodeNil(forKey: .hrbpId)
            try c.encode("", forKey: .buddyTrainer)
            try c.encode("", forKey: .mentor)
            try c.encode("", forKey: .hrbp)
            try c.encode(customerCode, forKey: .customerCode)
            try c.encode("", forKey: .serialNumber)
            // The mobile number doubles as the login id for an external trainer.
            try c.encode(mobileNumber, forKey: .userId)
            try c.encode(userName, forKey: .userName)
            try c.encode(emailId, forKey: .emailId)
            try c.encode(mobileNumber, forKey: .mobileNumber)
            try c.encode(Self.userRole, forKey: .userRole)
            try c.encode(Self.userType, forKey: .userType)
            try c.encode(Self.userSubType, forKey: .userSubType)
            try c.encode("", forKey: .gender)
            try c.encode("", forKey: .implicitRole)
            try c.encode(Self.timeZone, forKey: .timeZone)
            try c.encode(Self.currency, forKey: .currency)
            try c.encode(Self.language, forKey: .language)
            try c.encode("", forKey: .profilePicture)
            try c.encode("", forKey: .password)
            try c.encode(accountCreatedDate, forKey: .accountCreatedDate)
            try c.encode(accountExpiryDate, forKey: .accountExpiryDate)
            try c.encode(lastModifiedDate, forKey: .lastModifiedDate)
            try c.encode("", forKey: .lastModifiedDateNew)
            try c.encode("", forKey: .changedAttributes)
            try c.encode("", forKey: .oldData)
            try c.encode("", forKey: .reportsTo)
            try c.encode("", forKey: .business)
            try c.encode("", forKey: .group)
            try c.encode("", forKey: .area)
            try c.encode("", forKey: .location)
            try c.encodeNil(forKey: .dateOfBirth)
            try c.encodeNil(forKey: .dateIntoRole)
            try c.encodeNil(forKey: .dateOfJoining)
            for key in Self.configurationColumnKeys {
                try c.encode("", forKey: key)
            }
            try c.encode(true, forKey: .isActive)
            try c.encode(false, forKey: .isDeleted)
            try c.encode(false, forKey: .isEnableDegreed)
            try c.encode(false, forKey: .lock)
            try c.encode(false, forKey: .termsCondintionsAccepted)
            try c.encodeNil(forKey: .acceptanceDate)
            try c.encode("", forKey: .house)
            try c.encode("", forKey: .ceoMessageHeading)
            try c.encode("", forKey: .ceoMessageDescription)
            try c.encode("", forKey: .ceoProfilePicture)
            try c.encode(false, forKey: .isShowCEOMessageOnLandingPage)
            try c.encode(false, forKey: .isShowCEOMessageAfterLogin)
            try c.encode(true, forKey: .appearOnLeaderboard)
            try c.encode("", forKey: .jobRoleName)
            try c.encode("", forKey: .wallfeedRole)
            try c.encode("", forKey: .profabRole)
            try c.encode("", forKey: .federationId)
            try c.encode("", forKey: .country)
            try c.encodeNil(forKey: .vendorId)
            try c.encodeNil(forKey: .areaId)
            try c.encodeNil(forKey: .groupId)
            try c.encodeNil(forKey: .locationId)
            try c.encodeNil(forKey: .configurationColumn1Id)
        }

        private static let configurationColumnKeys: [CodingKeys] = [
            .configurationColumn1, .configurationColumn2, .configurationColumn3,
            .configurationColumn4, .configurationColumn5, .configurationColumn6,
            .configurationColumn7, .configurationColumn8, .configurationColumn9,
            .configurationColumn10, .configurationColumn11, .configurationColumn12,
            .configurationColumn13, .configurationColumn14, .configurationColumn15,
            .configurationColumn16, .configurationColumn17, .configurationColumn18,
            .configurationColumn19, .configurationColumn20
        ]
    }
}

// MARK: - Form → Payload

extension CreateTrainerDataModel.CreateUserPayload {

    /// Builds the create body from the sheet's three fields. `now` is injected so the
    /// account timestamps are pinnable in tests.
    init(form: CreateTrainerForm, customerCode: String, now: Date = Date(), calendar: Calendar = .current) {
        let created = now.isoInstantUTCString
        let expiry = calendar.date(byAdding: .year, value: Self.accountLifetimeYears, to: now) ?? now
        self.init(
            userName: form.trimmedName,
            emailId: form.trimmedEmail,
            mobileNumber: form.trimmedMobile,
            customerCode: customerCode,
            accountCreatedDate: created,
            accountExpiryDate: expiry.isoInstantUTCString,
            // The web client stamps all three from the same instant.
            lastModifiedDate: created
        )
    }
}

// MARK: - Response → Trainer

extension ScheduleLogisticsDataModel.Trainer {

    /// Maps a freshly created account onto the trainer shape `searchTrainer` returns, so a
    /// created trainer and a searched one are interchangeable downstream.
    ///
    /// `id` is re-encrypted from the plain numeric id because the create-schedule payload
    /// decrypts it back to `academyTrainerID`; every other identity field already arrives
    /// encrypted and is passed through. `nameUserId` is left nil so the chip and the payload
    /// fall back to `name` — the server does not return a composed display string here.
    init(created: CreateTrainerDataModel.CreateUserResponse, form: CreateTrainerForm) {
        self.init(
            id: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "\(created.id ?? 0)"),
            name: created.userName ?? form.trimmedName,
            emailId: created.emailId,
            userId: created.userId,
            profilePicture: nil,
            mobileNumber: created.mobileNumber,
            userType: created.userType ?? CreateTrainerDataModel.CreateUserPayload.userType,
            nameUserId: nil
        )
    }
}
